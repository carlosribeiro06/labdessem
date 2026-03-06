using JuMP
using HiGHS

import ..Data: OtimizacaoConfig

if !isdefined(@__MODULE__, :objective_expression)
    include(joinpath(@__DIR__, "objective.jl"))
end

"""
    build_milp(case; solver=HiGHS.Optimizer, silent=true, pi_demanda=1000)

Constrói o modelo MILP para o caso carregado via `LabDessem.IO.load_case`.

- solver: por padrão HiGHS.Optimizer
- silent: se true, desliga output do solver (HiGHS "output_flag" = false)
- pi_demanda: parâmetro usado na função objetivo (default 1000)

Mantém a mesma lógica de construção que você usava:
- variáveis por período (hidro, térmica, submercado, eólica)
- variável alpha (se cortes ativos)
- restrições:
  - limites intercâmbio (por período)
  - cadastro hidro/submercado/térmica (por período)
  - balanço de demanda (por período)
  - envelope McCormick (global)
  - ton/toff e rampas térmicas (se aciona_uct == 1)
  - ton/toff hidro (se aciona_uch == 1)
  - FPHA (por período)
  - cortes alpha (global)
- objetivo: objective_expression(...)
"""
function build_milp(
    case;
    solver = HiGHS.Optimizer,
    silent::Bool = true,
    pi_demanda::Real = 1000,
)
    etapa = "MILP"

    # -------------------- Modelo / Solver --------------------
    model = Model(solver)
    if silent
        try
            set_optimizer_attribute(model, "output_flag", false)
        catch
            # fallback: alguns wrappers podem não suportar esse atributo
        end
    end

    opt_config = OtimizacaoConfig()

    # Atalhos
    caso = case.config.caso
    registry = case.registry
    operation = case.operation

    # -------------------- Variáveis por período --------------------
    for periodo in 1:caso.n_periodos
        Components.Variables.add_hydro_variables!(model, opt_config, periodo, etapa, case.config, registry)
        Components.Variables.add_thermal_variables!(model, opt_config, periodo, etapa, case.config, registry)
        Components.Variables.add_submarket_variables!(model, opt_config, periodo, etapa, case.config, registry)
        Components.Variables.add_wind_variables!(model, opt_config, periodo, etapa, registry)
    end

    # Alpha (cortes externos)
    Components.Variables.add_alpha_variable!(model, opt_config, etapa, case.config)

    # -------------------- Restrições que dependem de séries (eólicas) --------------------
    Components.Constraints.add_wind_registry_constraints!(model, opt_config, etapa, registry, operation)

    # -------------------- Restrições por período --------------------
    for periodo in 1:caso.n_periodos
        Components.Constraints.add_interchange_limits_constraints!(model, opt_config, periodo, etapa, case.config, registry, operation)
        Components.Constraints.add_hydro_registry_constraints!(model, opt_config, periodo, etapa, case.config, registry, operation)
        Components.Constraints.add_submarket_registry_constraints!(model, opt_config, periodo, etapa, case.config.caso, registry)
        Components.Constraints.add_thermal_registry_constraints!(model, opt_config, periodo, etapa, case.config, registry)

        # Balanço de demanda por período
        Components.Constraints.add_balance_constraints!(model, opt_config, periodo, etapa, case.config, registry)
    end

    # -------------------- Envelope McCormick (global) --------------------
    Components.Constraints.add_interchange_mccormick_constraints!(model, opt_config, etapa, case.config, registry, operation)

    # -------------------- TON/TOFF e rampas térmicas --------------------
    if case.config.aciona_uct == 1
        Components.Constraints.add_thermal_ton_toff_constraints!(model, opt_config, etapa, case.config, registry)
        Components.Constraints.add_thermal_ramp_constraints!(model, opt_config, etapa, case.config, registry)
    end

    # -------------------- TON/TOFF hidro --------------------
    if case.config.aciona_uch == 1
        Components.Constraints.add_hydro_ton_toff_constraints!(model, opt_config, etapa, case.config, registry)
    end

    # -------------------- FPHA por período --------------------
    for periodo in 1:caso.n_periodos
        Components.Constraints.add_fpha_constraints!(model, opt_config, periodo, etapa, case.config, registry, operation)
    end

    # -------------------- Cortes alpha (global) --------------------
    Components.Constraints.add_alpha_cut_constraints!(model, opt_config, etapa, case.config, operation)

    # -------------------- Objetivo --------------------
    @objective(model, Min, objective_expression(opt_config, etapa, case.config, registry; pi_demanda = pi_demanda))

    return model, opt_config
end