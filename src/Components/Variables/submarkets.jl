using JuMP

"""
    add_submarket_variables!(model, opt_config, periodo, etapa, case_config, registry)

Cria as variáveis associadas aos submercados e adiciona as restrições básicas.

Lógica (mantida do original):
- Para cada submercado `sbm`:
  - Se `caso.Defs == 1`:
      deficit_vars[(periodo, sbm.nome, etapa)] = @variable(...)
- Para cada par `sbm != sbm_2`:
    intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa)] = @variable(...)
    @constraint(model, intercambio_vars[...] >= 0)

Entradas esperadas:
- `case_config`: NamedTuple contendo `caso` (CaseData) (ex.: `load_case(...).config`)
- `registry`: NamedTuple contendo `lista_submercados`
"""

function add_submarket_variables!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    caso = case_config.caso

    for sbm in registry.lista_submercados
        if caso.Defs == 1
            opt_config.deficit_vars[(periodo, sbm.nome, etapa_s)] =
                @variable(model, base_name = "def_$(periodo)_$(sbm.codigo)_$(etapa_s)")
        end

        for sbm_2 in registry.lista_submercados
            if sbm.codigo != sbm_2.codigo
                opt_config.intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa_s)] =
                    @variable(model, base_name = "interc_$(periodo)_$(sbm.codigo)_$(sbm_2.codigo)_$(etapa_s)")

                @constraint(model, opt_config.intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa_s)] >= 0)
            end
        end
    end

    return nothing
end