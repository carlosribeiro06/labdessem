using JuMP

"""
    add_thermal_ramp_constraints!(model, opt_config, etapa, case_config, registry)

Adiciona as restrições de rampas/acionamento/desligamento térmico.

Lógica mantida do original:
- Se existe_term > 0:
  - Para cada período e UTE:
      (uct[t] - uct[t-1]) == y[t] - w[t]  (com condição inicial em t=1)
      y[t] + w[t] <= 1
      0 <= y[t] <= 1
  - Para cada período e UTE:
      define somatórios de y e w ponderados por vetores de acionamento/desligamento
      e impõe:
        gt[t] >= pmin*(uct[t] - y_sum - w_sum) + trupy + trdnw
        gt[t] <= pmax*(uct[t] - y_sum - w_sum) + trupy + trdnw
"""
function add_thermal_ramp_constraints!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    caso = case_config.caso
    existe_term = registry.existe_term

    if existe_term > 0
        # ----------------------------------------------------------------------
        # 1) Relação uct - y - w e restrições básicas em y/w
        # ----------------------------------------------------------------------
        for periodo in 1:caso.n_periodos
            for ute in registry.lista_utes
                if periodo > 1
                    @constraint(
                        model,
                        (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] -
                         opt_config.uct_vars[(periodo - 1, ute.nome, etapa_s)]) ==
                        opt_config.y_vars[(periodo, ute.nome, etapa_s)] -
                        opt_config.w_vars[(periodo, ute.nome, etapa_s)]
                    )
                else
                    @constraint(
                        model,
                        (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - ute.stat_ini) ==
                        opt_config.y_vars[(periodo, ute.nome, etapa_s)] -
                        opt_config.w_vars[(periodo, ute.nome, etapa_s)]
                    )
                end

                @constraint(model, opt_config.y_vars[(periodo, ute.nome, etapa_s)] + opt_config.w_vars[(periodo, ute.nome, etapa_s)] <= 1)
                @constraint(model, opt_config.y_vars[(periodo, ute.nome, etapa_s)] >= 0)
                @constraint(model, opt_config.y_vars[(periodo, ute.nome, etapa_s)] <= 1)
            end
        end

        # ----------------------------------------------------------------------
        # 2) Rampas/acionamento/desligamento com vetores ute.acionamento/desligamento
        # ----------------------------------------------------------------------
        for periodo in 1:caso.n_periodos
            for ute in registry.lista_utes
                y = 0
                w = 0
                trupy = 0
                trdnw = 0

                for k in 1:length(ute.acionamento)
                    if (periodo - k + 1) >= 1
                        y += opt_config.y_vars[(periodo - k + 1, ute.nome, etapa_s)]
                        trupy += ute.acionamento[k] * opt_config.y_vars[(periodo - k + 1, ute.nome, etapa_s)]
                    end
                end

                for k in 1:length(ute.desligamento)
                    if (periodo + k) <= caso.n_periodos
                        w += opt_config.w_vars[(periodo + k, ute.nome, etapa_s)]
                        trdnw += ute.desligamento[length(ute.desligamento) - k + 1] * opt_config.w_vars[(periodo + k, ute.nome, etapa_s)]
                    end
                end

                @constraint(
                    model,
                    opt_config.gt_vars[(periodo, ute.nome, etapa_s)] >=
                    ute.pmin * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - y - w) + trupy + trdnw
                )

                @constraint(
                    model,
                    opt_config.gt_vars[(periodo, ute.nome, etapa_s)] <=
                    ute.pmax * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - y - w) + trupy + trdnw
                )
            end
        end
    end

    return nothing
end