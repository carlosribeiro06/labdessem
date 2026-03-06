using JuMP
using DataFrames

"""
    add_wind_registry_constraints!(model, opt_config, etapa, registry, operation)

Adiciona as restrições do cadastro de eólicas.

Lógica (mantida do original):
- Se existe_eol > 0:
  - Para cada eólica `eol`:
    - filtra `operation.dat_eol` por `row.nome == eol.nome`
    - para cada linha filtrada:
        geol_vars[(row.periodo, row.posto, row.nome, etapa)] >= 0
        geol_vars[(row.periodo, row.posto, row.nome, etapa)] <= row.programado

Entradas esperadas:
- `registry` com `existe_eol` e `lista_eols`
- `operation` com `dat_eol`
"""
function add_wind_registry_constraints!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    registry,
    operation,
)
    etapa_s = String(etapa)
    existe_eol = registry.existe_eol

    if existe_eol > 0
        dat_eol = operation.dat_eol

        for eol in registry.lista_eols
            dataFrameEol = filter(row -> row.nome == eol.nome, dat_eol)

            for row in eachrow(dataFrameEol)
                @constraint(model, opt_config.geol_vars[(row.periodo, row.posto, row.nome, etapa_s)] >= 0)
                @constraint(model, opt_config.geol_vars[(row.periodo, row.posto, row.nome, etapa_s)] <= row.programado)
            end
        end
    end

    return nothing
end