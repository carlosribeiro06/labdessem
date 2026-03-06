using JuMP

# Este arquivo é incluído em LabDessem.Components.Variables, então:
import ...Data: CaseData

"""
    add_alpha_variable!(model, opt_config, etapa, case_config)

Cria a variável `alpha` quando o caso usa cortes, ou define `alpha_vars = 0` caso contrário.

Lógica (mantida do original):
- Se caso.Cortes == 1:
    opt_config.alpha_vars = @variable(model, base_name = "alpha_<etapa>")
  Senão:
    opt_config.alpha_vars = 0

Nota: usamos "alpha_<etapa>" no texto para evitar interpolação de string no docstring.
"""
function add_alpha_variable!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
)
    etapa_s = String(etapa)
    caso::CaseData = case_config.caso

    if caso.Cortes == 1
        opt_config.alpha_vars = @variable(model, base_name = "alpha_$(etapa_s)")
    else
        opt_config.alpha_vars = 0
    end

    return nothing
end