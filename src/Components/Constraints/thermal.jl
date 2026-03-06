using JuMP

"""
    add_thermal_registry_constraints!(model, opt_config, periodo, etapa, case_config, registry)

Adiciona as restrições do cadastro de térmicas.

Lógica (mantida do original):
- Se existe_term > 0:
  - Se etapa == "PL":
      uct >= 0
      uct <= 1
      gt  <= pmax * uct
      gt  >= pmin * uct
  - Se aciona_uct == 0 e etapa == "MILP":
      mesmas restrições
  - Se aciona_uct == 0 e etapa == "PL_int_fix":
      mesmas restrições

Entradas esperadas:
- `case_config`: NamedTuple (ex.: de `read_case_config` ou `load_case(...).config`) contendo `aciona_uct`
- `registry`: NamedTuple (ex.: de `load_registry` ou `load_case(...).registry`) contendo `lista_utes` e `existe_term`
"""
function add_thermal_registry_constraints!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    aciona_uct = case_config.aciona_uct
    existe_term = registry.existe_term

    if existe_term > 0
        if etapa_s == "PL"
            for ute in registry.lista_utes
                @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] >= 0)
                @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] <= 1)
                @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] <= ute.pmax * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
                @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] >= ute.pmin * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
            end
        end

        if aciona_uct == 0
            if etapa_s == "MILP"
                for ute in registry.lista_utes
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] >= 0)
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] <= 1)
                    @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] <= ute.pmax * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
                    @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] >= ute.pmin * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
                end
            end

            if etapa_s == "PL_int_fix"
                for ute in registry.lista_utes
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] >= 0)
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] <= 1)
                    @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] <= ute.pmax * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
                    @constraint(model, opt_config.gt_vars[(periodo, ute.nome, etapa_s)] >= ute.pmin * opt_config.uct_vars[(periodo, ute.nome, etapa_s)])
                end
            end
        end
    end

    return nothing
end