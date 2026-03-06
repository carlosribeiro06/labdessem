using JuMP
using HiGHS

import ..Data: OtimizacaoConfig

if !isdefined(@__MODULE__, :objective_expression)
    include(joinpath(@__DIR__, "objective.jl"))
end

"""
    build_lp(case;
             etapa="PL",
             solver=HiGHS.Optimizer,
             silent=true,
             pi_demanda=1000,
             fixed=nothing,
             force_fix=true)

Constrói o modelo LP para o caso carregado via `LabDessem.IO.load_case`.

Etapas:
- "PL": LP padrão (sem ton/toff e rampas)
- "PL_int_fix": LP com inteiros fixados + restrições ton/toff e rampas (conforme seu fluxo)

Parâmetros:
- solver: por padrão HiGHS.Optimizer
- silent: desliga output do solver (HiGHS output_flag=false)
- pi_demanda: parâmetro usado na função objetivo (default 1000)
- fixed: opcional, para fixação de inteiros (commitment) quando etapa=="PL_int_fix"
    Espera um NamedTuple com alguns dos campos abaixo (todos opcionais):
      fixed.uct :: Dict{Tuple{Int,String},Real}   # chave (periodo, ute_nome)
      fixed.y   :: Dict{Tuple{Int,String},Real}
      fixed.w   :: Dict{Tuple{Int,String},Real}
      fixed.uch :: Dict{Tuple{Int,String,Int,Int},Real} # (periodo,uhe_nome,conj_codigo,unidade_codigo)
- force_fix: passa `force=true` para JuMP.fix

Lógica de restrições:
- Sempre no LP ("PL" e "PL_int_fix"):
  - limites intercâmbio (por período)
  - cadastro hidro/submercado/térmica (por período)
  - balanço de demanda (por período)
  - FPHA (por período)
  - cortes alpha (global)
  - limites eólicos (global, via wind registry constraints)
- Somente em "PL_int_fix":
  - ton/toff térmicas + rampas térmicas (se aciona_uct == 1)
  - ton/toff hidro (se aciona_uch == 1)
"""
function build_lp(
    case;
    etapa::AbstractString = "PL",
    solver = HiGHS.Optimizer,
    silent::Bool = true,
    pi_demanda::Real = 1000,
    fixed = nothing,
    force_fix::Bool = true,
)
    etapa_s = String(etapa)

    if !(etapa_s in ("PL", "PL_int_fix"))
        error("Etapa inválida para LP: $(etapa_s). Use \"PL\" ou \"PL_int_fix\".")
    end

    # -------------------- Modelo / Solver --------------------
    model = Model(solver)
    if silent
        try
            set_optimizer_attribute(model, "output_flag", false)
        catch
        end
    end

    opt_config = OtimizacaoConfig()

    # Atalhos
    caso = case.config.caso
    registry = case.registry
    operation = case.operation

    # -------------------- Variáveis por período --------------------
    for periodo in 1:caso.n_periodos
        Components.Variables.add_hydro_variables!(model, opt_config, periodo, etapa_s, case.config, registry)
        Components.Variables.add_thermal_variables!(model, opt_config, periodo, etapa_s, case.config, registry)
        Components.Variables.add_submarket_variables!(model, opt_config, periodo, etapa_s, case.config, registry)
        Components.Variables.add_wind_variables!(model, opt_config, periodo, etapa_s, registry)
    end

    # Alpha (cortes externos)
    Components.Variables.add_alpha_variable!(model, opt_config, etapa_s, case.config)

    # -------------------- Fixação de inteiros (somente PL_int_fix) --------------------
    if etapa_s == "PL_int_fix"
        if fixed === nothing
            @info "Etapa PL_int_fix sem `fixed`: nenhuma variável será fixada (apenas restrições ton/toff+rampas serão adicionadas)."
        else
            # térmicas: uct / y / w
            if case.config.aciona_uct == 1 && registry.existe_term > 0
                if hasproperty(fixed, :uct)
                    for (k, val) in fixed.uct
                        # k = (periodo, ute_nome)
                        fix(opt_config.uct_vars[(k[1], k[2], etapa_s)], val; force = force_fix)
                    end
                end
                if hasproperty(fixed, :y)
                    for (k, val) in fixed.y
                        fix(opt_config.y_vars[(k[1], k[2], etapa_s)], val; force = force_fix)
                    end
                end
                if hasproperty(fixed, :w)
                    for (k, val) in fixed.w
                        fix(opt_config.w_vars[(k[1], k[2], etapa_s)], val; force = force_fix)
                    end
                end
            end

            # hidros: uch
            if case.config.aciona_uch == 1 && registry.existe_hid > 0
                if hasproperty(fixed, :uch)
                    for (k, val) in fixed.uch
                        # k = (periodo, uhe_nome, conj_codigo, unidade_codigo)
                        fix(opt_config.uch_vars[(k[1], k[2], k[3], k[4], etapa_s)], val; force = force_fix)
                    end
                end
            end
        end
    end

    # -------------------- Restrições eólicas (limites programado) --------------------
    # (no seu legado: cadastra_eolica(model, opt_config, etapa) antes do loop de períodos)
    Components.Constraints.add_wind_registry_constraints!(model, opt_config, etapa_s, registry, operation)

    # -------------------- Restrições por período --------------------
    for periodo in 1:caso.n_periodos
        # Limites de intercâmbio
        Components.Constraints.add_interchange_limits_constraints!(model, opt_config, periodo, etapa_s, case.config, registry, operation)

        # Cadastros por período (mesma sequência do seu fluxo)
        Components.Constraints.add_hydro_registry_constraints!(model, opt_config, periodo, etapa_s, case.config, registry, operation)
        Components.Constraints.add_submarket_registry_constraints!(model, opt_config, periodo, etapa_s, case.config.caso, registry)
        Components.Constraints.add_thermal_registry_constraints!(model, opt_config, periodo, etapa_s, case.config, registry)

        # Balanço de demanda
        Components.Constraints.add_balance_constraints!(model, opt_config, periodo, etapa_s, case.config, registry)

        # FPHA por período (no legado era depois do loop principal, mas matematicamente independente)
        Components.Constraints.add_fpha_constraints!(model, opt_config, periodo, etapa_s, case.config, registry, operation)
    end

    # -------------------- Restrições extras somente PL_int_fix --------------------
    if etapa_s == "PL_int_fix"
        if case.config.aciona_uct == 1
            Components.Constraints.add_thermal_ton_toff_constraints!(model, opt_config, etapa_s, case.config, registry)
            Components.Constraints.add_thermal_ramp_constraints!(model, opt_config, etapa_s, case.config, registry)
        end
        if case.config.aciona_uch == 1
            Components.Constraints.add_hydro_ton_toff_constraints!(model, opt_config, etapa_s, case.config, registry)
        end
    end

    # -------------------- Cortes alpha (global) --------------------
    Components.Constraints.add_alpha_cut_constraints!(model, opt_config, etapa_s, case.config, operation)

    # -------------------- Objetivo --------------------
    @objective(model, Min, objective_expression(opt_config, etapa_s, case.config, registry; pi_demanda = pi_demanda))

    return model, opt_config
end