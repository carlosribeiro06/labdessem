using JuMP

import ...Data: CaseData, OtimizacaoConfig

"""
    add_submarket_registry_constraints!(model, opt_config, periodo, etapa, caso, registry)

Adiciona as restrições do cadastro de submercados.

Lógica (mantida do original):
- Se `caso.Defs == 1`, para cada submercado:
  deficit_vars[(periodo, sbm.nome, etapa)] >= 0
"""
function add_submarket_registry_constraints!(
    model::JuMP.Model,
    opt_config::OtimizacaoConfig,
    periodo::Integer,
    etapa::AbstractString,
    caso::CaseData,
    registry,
)
    if caso.Defs == 1
        for sbm in registry.lista_submercados
            @constraint(model, opt_config.deficit_vars[(periodo, sbm.nome, String(etapa))] >= 0)
        end
    end
    return nothing
end