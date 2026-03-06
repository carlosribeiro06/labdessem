using JuMP

"""
    add_thermal_ton_toff_constraints!(model, opt_config, etapa, case_config, registry)

Adiciona restrições de TON/TOFF para térmicas.

Lógica mantida do original:
- Se existe_term > 0:
  Para cada UTE:
    (A) Se inicia desligada e não cumpriu TOFF:
        fixa uct=0 nos períodos necessários
        depois aplica janela TOFF
    (B) Se inicia ligada e não cumpriu TON:
        fixa uct=1 nos períodos necessários
        depois aplica janela TON
    (C) Caso geral quando ton_toff_ini já excedeu:
        aplica TON e TOFF em janelas móveis, com condição inicial em t=1

"""

function add_thermal_ton_toff_constraints!(
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
        for ute in registry.lista_utes

            # ------------------------------------------------------------------
            # (A) Inicial desligada e ainda não cumpriu TOFF
            # ------------------------------------------------------------------
            if (ute.stat_ini == 0) && (ute.ton_toff_ini < ute.toff)
                for periodo in 1:(ute.toff - ute.ton_toff_ini)
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] == 0)
                end

                for periodo in (ute.toff - ute.ton_toff_ini + 1):caso.n_periodos
                    toff = min(ute.toff, caso.n_periodos - periodo + 1)
                    toff_vector = Vector{Int32}(periodo:(toff + periodo - 1))

                    @constraint(
                        model,
                        sum((1 - opt_config.uct_vars[(ts, ute.nome, etapa_s)]) for ts in toff_vector) >=
                        -toff * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - opt_config.uct_vars[(periodo - 1, ute.nome, etapa_s)])
                    )
                end
            end

            # ------------------------------------------------------------------
            # (B) Inicial ligada e ainda não cumpriu TON
            # ------------------------------------------------------------------
            if (ute.stat_ini == 1) && (ute.ton_toff_ini < ute.ton)
                for periodo in 1:(ute.ton - ute.ton_toff_ini)
                    @constraint(model, opt_config.uct_vars[(periodo, ute.nome, etapa_s)] == 1)
                end

                for periodo in (ute.ton - ute.ton_toff_ini + 1):caso.n_periodos
                    ton = min(ute.ton, caso.n_periodos - periodo + 1)
                    ton_vector = Vector{Int32}(periodo:(ton + periodo - 1))

                    @constraint(
                        model,
                        sum(opt_config.uct_vars[(ts, ute.nome, etapa_s)] for ts in ton_vector) >=
                        ton * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - opt_config.uct_vars[(periodo - 1, ute.nome, etapa_s)])
                    )
                end
            end

            # ------------------------------------------------------------------
            # (C) Caso geral quando ton_toff_ini excede o mínimo
            # ------------------------------------------------------------------
            if ((ute.stat_ini == 0) && (ute.ton_toff_ini > ute.toff)) | ((ute.stat_ini == 1) && (ute.ton_toff_ini > ute.ton))

                # TON
                for periodo in 1:caso.n_periodos
                    ton = min(ute.ton, caso.n_periodos - periodo + 1)

                    if periodo == 1
                        ton_vector = Vector{Int32}(periodo:ton)
                        @constraint(
                            model,
                            sum(opt_config.uct_vars[(ts, ute.nome, etapa_s)] for ts in ton_vector) >=
                            ton * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - ute.stat_ini)
                        )
                    end

                    if periodo > 1
                        ton_vector = Vector{Int32}(periodo:(ton + periodo - 1))
                        @constraint(
                            model,
                            sum(opt_config.uct_vars[(ts, ute.nome, etapa_s)] for ts in ton_vector) >=
                            ton * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - opt_config.uct_vars[(periodo - 1, ute.nome, etapa_s)])
                        )
                    end
                end

                # TOFF
                for periodo in 1:caso.n_periodos
                    toff = min(ute.toff, caso.n_periodos - periodo + 1)

                    if periodo == 1
                        toff_vector = Vector{Int32}(periodo:toff)
                        @constraint(
                            model,
                            sum((1 - opt_config.uct_vars[(ts, ute.nome, etapa_s)]) for ts in toff_vector) >=
                            -toff * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - ute.stat_ini)
                        )
                    end

                    if periodo > 1
                        toff_vector = Vector{Int32}(periodo:(toff + periodo - 1))
                        @constraint(
                            model,
                            sum((1 - opt_config.uct_vars[(ts, ute.nome, etapa_s)]) for ts in toff_vector) >=
                            -toff * (opt_config.uct_vars[(periodo, ute.nome, etapa_s)] - opt_config.uct_vars[(periodo - 1, ute.nome, etapa_s)])
                        )
                    end
                end
            end
        end
    end

    return nothing
end