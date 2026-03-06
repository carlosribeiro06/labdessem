using JuMP

"""
    add_wind_variables!(model, opt_config, periodo, etapa, registry)

Cria as variáveis associadas às eólicas.

Lógica (mantida do original):
- Se existe_eol > 0:
  - para cada eol em lista_eols:
      geol_vars[(periodo, eol.posto, eol.nome, etapa)] = @variable(...)
"""
function add_wind_variables!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    registry,
)
    etapa_s = String(etapa)
    existe_eol = registry.existe_eol

    if existe_eol > 0
        for eol in registry.lista_eols
            opt_config.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)] =
                @variable(model, base_name = "geol_$(periodo)_$(eol.posto)_$(eol.nome)_$(etapa_s)")
        end
    end

    return nothing
end