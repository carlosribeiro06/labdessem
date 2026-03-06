module LabDessem

# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------
module Data
    include(joinpath(@__DIR__, "Data", "types.jl"))

    export CaseData,
           OtimizacaoConfig,
           Output,
           SubmercadoConfigData,
           EOLConfigData,
           UTEConfigData,
           UHEConfigData,
           CONJ_MAQConfig,
           UnidadeHidreletricaConfig,
           Info_Linhas,
           Info_Barras,
           Violacao_Rede,
           Alphas,
           FPHA
end

# ------------------------------------------------------------------------------
# IO
# ------------------------------------------------------------------------------
module IO
    import ..Data

    include(joinpath(@__DIR__, "IO", "load_case_config.jl"))
    include(joinpath(@__DIR__, "IO", "load_registry.jl"))
    include(joinpath(@__DIR__, "IO", "load_operation_data.jl"))
    include(joinpath(@__DIR__, "IO", "load_case.jl"))

    export read_case_config,
           load_registry,
           load_operation_data,
           load_case
end

# ------------------------------------------------------------------------------
# Components (Variables + Constraints)
# ------------------------------------------------------------------------------
module Components

    module Variables
        include(joinpath(@__DIR__, "Components", "Variables", "submarkets.jl"))
        include(joinpath(@__DIR__, "Components", "Variables", "thermal.jl"))
        include(joinpath(@__DIR__, "Components", "Variables", "hydro.jl"))
        include(joinpath(@__DIR__, "Components", "Variables", "wind.jl"))
        include(joinpath(@__DIR__, "Components", "Variables", "alpha.jl"))

        export add_submarket_variables!,
               add_thermal_variables!,
               add_hydro_variables!,
               add_wind_variables!,
               add_alpha_variable!

        # wrappers legados (opcional durante migração)
        export variavel_submercado,
               variavel_termica,
               variavel_hidreletrica,
               variavel_eolica,
               variavel_alpha
    end

    module Constraints
        # Cadastro
        include(joinpath(@__DIR__, "Components", "Constraints", "submarkets.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "thermal.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "hydro.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "wind.jl"))

        # Operativas
        include(joinpath(@__DIR__, "Components", "Constraints", "balance.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "interchange_limits.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "interchange_mccormick.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "thermal_ramps.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "thermal_ton_toff.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "hydro_ton_toff.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "fpha.jl"))
        include(joinpath(@__DIR__, "Components", "Constraints", "alpha_cuts.jl"))

        export add_submarket_registry_constraints!,
               add_thermal_registry_constraints!,
               add_hydro_registry_constraints!,
               add_wind_registry_constraints!

        export add_balance_constraints!,
               add_interchange_limits_constraints!,
               add_interchange_mccormick_constraints!,
               add_thermal_ramp_constraints!,
               add_thermal_ton_toff_constraints!,
               add_hydro_ton_toff_constraints!,
               add_fpha_constraints!,
               add_alpha_cut_constraints!

        # wrappers legados (opcional durante migração)
        export cadastra_submercado,
               cadastra_termica,
               cadastra_hidreletrica,
               cadastra_eolica

        export oper_balanco_demanda,
               oper_limite_intercambio,
               oper_limite_intercambio_envelope_mccormick,
               oper_rampa_termica,
               oper_ton_toff_termicas,
               oper_ton_toff_hidreletricas,
               oper_fpha,
               oper_alpha
    end

    export Variables, Constraints
end

# ------------------------------------------------------------------------------
# Network
# ------------------------------------------------------------------------------
module Network
    import ..Data

    include(joinpath(@__DIR__, "Network", "dc_flow.jl"))
    include(joinpath(@__DIR__, "Network", "check_violations.jl"))
    include(joinpath(@__DIR__, "Network", "add_flow_cuts.jl"))

    export build_B,
           build_B_diag,
           build_A,
           build_P,
           build_G,
           build_ptdf,
           check_network_violations,
           add_flow_cuts!

    # wrappers legados (opcional)
    export calculate_B,
           calculate_B_diag,
           calculate_A,
           calculate_P,
           calculate_G
end

# ------------------------------------------------------------------------------
# Models
# ------------------------------------------------------------------------------
module Models
    import ..Data
    import ..Components
    import ..IO
    import ..Network

    include(joinpath(@__DIR__, "Models", "objective.jl"))
    include(joinpath(@__DIR__, "Models", "milp.jl"))
    include(joinpath(@__DIR__, "Models", "lp.jl"))
    include(joinpath(@__DIR__, "Models", "extract_commitment.jl"))

    export objective_expression,
           build_milp,
           build_lp,
           extract_commitment
end

# ------------------------------------------------------------------------------
# Algorithms
# ------------------------------------------------------------------------------
module Algorithms
    import ..Models
    import ..Network
    import ..Data

    include(joinpath(@__DIR__, "Algorithms", "run_dispatch.jl"))

    export run_dispatch, DispatchResult
end

# ------------------------------------------------------------------------------
# Reports
# ------------------------------------------------------------------------------
module Reports
    import ..Data
    import ..IO
    import ..Models
    import ..Network

    include(joinpath(@__DIR__, "Reports", "extract_output.jl"))
    include(joinpath(@__DIR__, "Reports", "export_csv.jl"))

    export extract_output,
           export_ute_csv,
           export_uhe_csv,
           export_eol_csv,
           export_cost_csv,
           export_cmo_csv,
           export_network_flows_csv
end
# ------------------------------------------------------------------------------
# Export de alto nível
# ------------------------------------------------------------------------------
export Data, IO, Components, Network, Models, Algorithms, Reports

end # module LabDessem