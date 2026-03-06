using JuMP
using Logging

import ..Models
import ..Network
import ..Reports
import ..Data: Violacao_Rede

Base.@kwdef mutable struct DispatchResult
    total_solve_time::Float64 = 0.0
    lp_iters::Int = 0
    fix_iters::Int = 0
    violations::Vector{Violacao_Rede} = Violacao_Rede[]
    last_has_violation::Bool = false

    lp_model::Union{Nothing,JuMP.Model} = nothing
    lp_opt::Any = nothing

    milp_model::Union{Nothing,JuMP.Model} = nothing
    milp_opt::Any = nothing

    fix_model::Union{Nothing,JuMP.Model} = nothing
    fix_opt::Any = nothing

    cmo_model::Union{Nothing,JuMP.Model} = nothing
    cmo_opt::Any = nothing

    # caminhos gerados
    outputs::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

function _safe_solve_time(m::JuMP.Model)
    try
        return JuMP.solve_time(m)
    catch
        return 0.0
    end
end

"""
    run_dispatch(case;
                 max_lp_iters=50,
                 max_fix_iters=50,
                 round_digits=4,
                 pi_demanda=1000,
                 silent=true,
                 write_outputs=true)

Executa o fluxo completo do despacho

Saídas:
- out_termicas_<etapa>/geracoes_termicas.csv
- out_hidreletricas_<etapa>/hidreletricas.csv e ugh.csv
- out_eolicas_<etapa>/geracoes_eolicas.csv
- out_cmo/cmos.csv
- out_custo_<etapa>/custo_total_operacao.csv
- out_rede_<etapa>/fluxos.csv (se Rede==1)
"""
function run_dispatch(
    case;
    max_lp_iters::Int = 50,
    max_fix_iters::Int = 50,
    round_digits::Int = 4,
    pi_demanda::Real = 1000,
    silent::Bool = true,
    write_outputs::Bool = true,
)
    res = DispatchResult()
    violations_all = Violacao_Rede[]
    flow_violation = false

    # -------------------------------------------------------------------------
    # (1) PLs iterativos
    # -------------------------------------------------------------------------
    for iter in 1:max_lp_iters
        res.lp_iters = iter

        model, opt = Models.build_lp(case; etapa="PL", silent=silent, pi_demanda=pi_demanda)

        if !isempty(violations_all)
            Network.add_flow_cuts!(model, opt, "PL", case.config, case.registry, case.operation, violations_all)
        end

        @info "PL" iter=iter
        optimize!(model)
        res.total_solve_time += _safe_solve_time(model)

        @info "PL result" status=termination_status(model) obj=objective_value(model)

        new_viol, flow_violation, _ = Network.check_network_violations(
            opt, "PL", case.config, case.registry, case.operation;
            round_digits=round_digits
        )

        if flow_violation
            append!(violations_all, new_viol)
            @info "PL violations" iter=iter n_new=length(new_viol) n_total=length(violations_all)
        else
            res.lp_model = model
            res.lp_opt = opt
            break
        end
    end

    # -------------------------------------------------------------------------
    # (2) MILP
    # -------------------------------------------------------------------------
    model_milp, opt_milp = Models.build_milp(case; silent=silent, pi_demanda=pi_demanda)
    if !isempty(violations_all)
        Network.add_flow_cuts!(model_milp, opt_milp, "MILP", case.config, case.registry, case.operation, violations_all)
    end

    @info "MILP"
    optimize!(model_milp)
    res.total_solve_time += _safe_solve_time(model_milp)

    res.milp_model = model_milp
    res.milp_opt = opt_milp

    @info "MILP result" status=termination_status(model_milp) obj=objective_value(model_milp)

    new_viol, flow_violation, _ = Network.check_network_violations(
        opt_milp, "MILP", case.config, case.registry, case.operation;
        round_digits=round_digits
    )
    if flow_violation
        append!(violations_all, new_viol)
        @info "MILP violations" n_new=length(new_viol) n_total=length(violations_all)
    end

    # -------------------------------------------------------------------------
    # (3) PL_int_fix iterativo (se MILP violou)
    # -------------------------------------------------------------------------
    fixed = nothing
    if flow_violation
        fixed = Models.extract_commitment(case, opt_milp; etapa="MILP")

        for iter in 1:max_fix_iters
            res.fix_iters = iter

            model_fix, opt_fix = Models.build_lp(case; etapa="PL_int_fix", fixed=fixed, silent=silent, pi_demanda=pi_demanda)

            if !isempty(violations_all)
                Network.add_flow_cuts!(model_fix, opt_fix, "PL_int_fix", case.config, case.registry, case.operation, violations_all)
            end

            @info "PL_int_fix" iter=iter
            optimize!(model_fix)
            res.total_solve_time += _safe_solve_time(model_fix)

            @info "PL_int_fix result" status=termination_status(model_fix) obj=objective_value(model_fix)

            new_viol, flow_violation, _ = Network.check_network_violations(
                opt_fix, "PL_int_fix", case.config, case.registry, case.operation;
                round_digits=round_digits
            )

            if flow_violation
                append!(violations_all, new_viol)
                @info "PL_int_fix violations" iter=iter n_new=length(new_viol) n_total=length(violations_all)
            else
                res.fix_model = model_fix
                res.fix_opt = opt_fix
                break
            end
        end
    end

    # -------------------------------------------------------------------------
    # (4) PL_calc_cmo: resolve um PL_int_fix final para extrair duais/CMO e gerar saída
    # -------------------------------------------------------------------------
    if fixed === nothing
        fixed = Models.extract_commitment(case, opt_milp; etapa="MILP")
    end

    etapa_final = "PL_int_fix"  # mantemos o mesmo comportamento do legado

    model_cmo, opt_cmo = Models.build_lp(case; etapa=etapa_final, fixed=fixed, silent=silent, pi_demanda=pi_demanda)
    if !isempty(violations_all)
        Network.add_flow_cuts!(model_cmo, opt_cmo, etapa_final, case.config, case.registry, case.operation, violations_all)
    end

    @info "PL_calc_cmo"
    optimize!(model_cmo)
    res.total_solve_time += _safe_solve_time(model_cmo)

    res.cmo_model = model_cmo
    res.cmo_opt = opt_cmo

    @info "PL_calc_cmo result" status=termination_status(model_cmo) obj=objective_value(model_cmo)

    # -------------------------------------------------------------------------
    # Geração de saídas CSV
    # -------------------------------------------------------------------------
    if write_outputs
        saida = Reports.extract_output(model_cmo, opt_cmo, etapa_final, case)

        res.outputs[:ute]  = Reports.export_ute_csv(case, saida, etapa_final)
        res.outputs[:uhe]  = Reports.export_uhe_csv(case, saida, etapa_final)
        res.outputs[:eol]  = Reports.export_eol_csv(case, saida, etapa_final)
        res.outputs[:cmo]  = Reports.export_cmo_csv(case, saida, opt_cmo, etapa_final)
        res.outputs[:cost] = Reports.export_cost_csv(case, saida, opt_cmo, etapa_final, res.total_solve_time)

        # Rede só se estiver ligada
        res.outputs[:network] = Reports.export_network_flows_csv(case, saida, etapa_final; round_digits=round_digits)

        @info "Saídas CSV geradas" out_dir=case.out_dir
    end

    res.violations = violations_all
    res.last_has_violation = flow_violation
    return res
end