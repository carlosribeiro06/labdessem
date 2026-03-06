using JuMP

"""
    add_hydro_ton_toff_constraints!(model, opt_config, etapa, case_config, registry)

Adiciona restrições de TON/TOFF para unidades hidrelétricas.

Lógica mantida do original:
- Se existe_hid > 0:
  Para cada UHE, conjunto e unidade (UGH):
    (A) Se inicia desligada e não cumpriu TOFF:
        fixa uch=0 nos períodos necessários
        depois aplica janela TOFF
    (B) Se inicia ligada e não cumpriu TON:
        fixa uch=1 nos períodos necessários
        depois aplica janela TON
    (C) Caso geral quando ton_toff_ini excede o mínimo:
        aplica TON e TOFF em janelas móveis, com condição inicial em t=1

"""

function add_hydro_ton_toff_constraints!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    caso = case_config.caso
    existe_hid = registry.existe_hid

    if existe_hid > 0
        for uhe in registry.lista_uhes
            for conj in uhe.conjunto
                for ugh in conj.unidades

                    # ----------------------------------------------------------
                    # (A) Inicial desligada e ainda não cumpriu TOFF
                    # ----------------------------------------------------------
                    if (ugh.stat_ini == 0) && (ugh.ton_toff_ini < ugh.toff)
                        for periodo in 1:(ugh.toff - ugh.ton_toff_ini)
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] == 0)
                        end

                        for periodo in (ugh.toff - ugh.ton_toff_ini + 1):caso.n_periodos
                            toff = min(ugh.toff, caso.n_periodos - periodo + 1)
                            toff_vector = Vector{Int32}(periodo:(toff + periodo - 1))

                            c = @constraint(
                                model,
                                sum((1 - opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]) for ts in toff_vector) >=
                                -toff * (
                                    opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] -
                                    opt_config.uch_vars[(periodo - 1, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]
                                )
                            )
                            JuMP.set_name(c, "Toff_hidreletricas")
                        end
                    end

                    # ----------------------------------------------------------
                    # (B) Inicial ligada e ainda não cumpriu TON
                    # ----------------------------------------------------------
                    if (ugh.stat_ini == 1) && (ugh.ton_toff_ini < ugh.ton)
                        for periodo in 1:(ugh.ton - ugh.ton_toff_ini)
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] == 1)
                        end

                        for periodo in (ugh.ton - ugh.ton_toff_ini + 1):caso.n_periodos
                            ton = min(ugh.ton, caso.n_periodos - periodo + 1)
                            ton_vector = Vector{Int32}(periodo:(ton + periodo - 1))

                            c = @constraint(
                                model,
                                sum(opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] for ts in ton_vector) >=
                                ton * (
                                    opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] -
                                    opt_config.uch_vars[(periodo - 1, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]
                                )
                            )
                            JuMP.set_name(c, "Ton_hidreletricas")
                        end
                    end

                    # ----------------------------------------------------------
                    # (C) Caso geral quando ton_toff_ini excede o mínimo
                    # ----------------------------------------------------------
                    if ((ugh.stat_ini == 0) && (ugh.ton_toff_ini > ugh.toff)) | ((ugh.stat_ini == 1) && (ugh.ton_toff_ini > ugh.ton))

                        # TON
                        for periodo in 1:caso.n_periodos
                            ton = min(ugh.ton, caso.n_periodos - periodo + 1)

                            if periodo == 1
                                ton_vector = Vector{Int32}(periodo:ton)
                                c = @constraint(
                                    model,
                                    sum(opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] for ts in ton_vector) >=
                                    ton * (opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] - ugh.stat_ini)
                                )
                                JuMP.set_name(c, "Ton_hidreletricas")
                            end

                            if periodo > 1
                                ton_vector = Vector{Int32}(periodo:(ton + periodo - 1))
                                c = @constraint(
                                    model,
                                    sum(opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] for ts in ton_vector) >=
                                    ton * (
                                        opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] -
                                        opt_config.uch_vars[(periodo - 1, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]
                                    )
                                )
                                JuMP.set_name(c, "Ton_hidreletricas")
                            end
                        end

                        # TOFF
                        for periodo in 1:caso.n_periodos
                            toff = min(ugh.toff, caso.n_periodos - periodo + 1)

                            if periodo == 1
                                toff_vector = Vector{Int32}(periodo:toff)
                                c = @constraint(
                                    model,
                                    sum((1 - opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]) for ts in toff_vector) >=
                                    -toff * (opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] - ugh.stat_ini)
                                )
                                JuMP.set_name(c, "Toff_hidreletricas")
                            end

                            if periodo > 1
                                toff_vector = Vector{Int32}(periodo:(toff + periodo - 1))
                                c = @constraint(
                                    model,
                                    sum((1 - opt_config.uch_vars[(ts, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]) for ts in toff_vector) >=
                                    -toff * (
                                        opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] -
                                        opt_config.uch_vars[(periodo - 1, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]
                                    )
                                )
                                JuMP.set_name(c, "Toff_hidreletricas")
                            end
                        end
                    end
                end
            end
        end
    end

    return nothing
end