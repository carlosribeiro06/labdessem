using JuMP

"""
    add_thermal_variables!(model, opt_config, periodo, etapa, case_config, registry)

Cria as variáveis associadas às térmicas.

Lógica (mantida do original):
- Se existe_term > 0:
  - para cada ute:
    - gt_vars[(periodo, ute.nome, etapa)] = @variable(...)
    - dependendo da etapa:
      - MILP:
          se aciona_uct==1: uct binária, y contínua, w binária
          se aciona_uct==0: uct contínua
      - PL_int_fix:
          se aciona_uct==1: uct contínua, y contínua, w contínua
          se aciona_uct==0: uct contínua
      - PL:
          uct contínua
"""
function add_thermal_variables!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    existe_term = registry.existe_term
    aciona_uct = case_config.aciona_uct

    if existe_term > 0
        for ute in registry.lista_utes
            # geração térmica
            opt_config.gt_vars[(periodo, ute.nome, etapa_s)] =
                @variable(model, base_name = "gt_$(periodo)_$(ute.codigo)_$(etapa_s)")

            if etapa_s == "MILP"
                if aciona_uct == 1
                    opt_config.uct_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "uct_$(periodo)_$(ute.codigo)_$(etapa_s)", binary = true)

                    opt_config.y_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "y_$(periodo)_$(ute.codigo)_$(etapa_s)")

                    opt_config.w_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "w_$(periodo)_$(ute.codigo)_$(etapa_s)", binary = true)
                end

                if aciona_uct == 0
                    opt_config.uct_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "uct_$(periodo)_$(ute.codigo)_$(etapa_s)")
                end
            end

            if etapa_s == "PL_int_fix"
                if aciona_uct == 1
                    opt_config.uct_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "uct_$(periodo)_$(ute.codigo)_$(etapa_s)")

                    opt_config.y_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "y_$(periodo)_$(ute.codigo)_$(etapa_s)")

                    opt_config.w_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "w_$(periodo)_$(ute.codigo)_$(etapa_s)")
                end

                if aciona_uct == 0
                    opt_config.uct_vars[(periodo, ute.nome, etapa_s)] =
                        @variable(model, base_name = "uct_$(periodo)_$(ute.codigo)_$(etapa_s)")
                end
            end

            if etapa_s == "PL"
                opt_config.uct_vars[(periodo, ute.nome, etapa_s)] =
                    @variable(model, base_name = "uct_$(periodo)_$(ute.codigo)_$(etapa_s)")
            end
        end
    end

    return nothing
end