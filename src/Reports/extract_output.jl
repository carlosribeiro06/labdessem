using JuMP
import ..Data: Output

"""
    extract_output(model::JuMP.Model, opt_config, etapa::AbstractString, case) -> Output

Extrai os valores das variáveis do `opt_config` (via `value`) e retorna um `Output`
preenchido, no mesmo espírito do `valores_saida.jl` legado, porém sem globais.

Parâmetros:
- `model`: JuMP.Model já otimizado
- `opt_config`: OtimizacaoConfig retornado por Models.build_lp/build_milp
- `etapa`: "PL", "MILP", "PL_int_fix", ...
- `case`: NamedTuple retornado por IO.load_case (contém config/registry/operation)

Retorna:
- `saida::Output` com dicionários preenchidos:
  geol_vars, gt_vars, uct_vars, y_vars, w_vars, gh_vars, turb_vars, uch_vars,
  vert_vars, vf_vars, deficit_vars, intercambio_vars
"""
function extract_output(model::JuMP.Model, opt_config, etapa::AbstractString, case)
    etapa_s = String(etapa)
    cfg = case.config
    reg = case.registry
    caso = cfg.caso

    saida = Output()
    saida.model = model

    for periodo in 1:caso.n_periodos
        # -------------------------
        # Eólicas (geol)
        # -------------------------
        if reg.existe_eol > 0
            for eol in reg.lista_eols
                saida.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)] =
                    value(opt_config.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)])
            end
        end

        # -------------------------
        # Térmicas (gt, uct, y, w)
        # -------------------------
        if reg.existe_term > 0
            for ute in reg.lista_utes
                saida.gt_vars[(periodo, ute.nome, etapa_s)] =
                    value(opt_config.gt_vars[(periodo, ute.nome, etapa_s)])
            end

            for ute in reg.lista_utes
                if etapa_s == "MILP" || etapa_s == "PL_int_fix"
                    saida.uct_vars[(periodo, ute.nome, etapa_s)] =
                        value(opt_config.uct_vars[(periodo, ute.nome, etapa_s)])

                    if cfg.aciona_uct == 1
                        # y e w só existem quando commitment ativo
                        if haskey(opt_config.y_vars, (periodo, ute.nome, etapa_s))
                            saida.y_vars[(periodo, ute.nome, etapa_s)] =
                                value(opt_config.y_vars[(periodo, ute.nome, etapa_s)])
                        end
                        if haskey(opt_config.w_vars, (periodo, ute.nome, etapa_s))
                            saida.w_vars[(periodo, ute.nome, etapa_s)] =
                                value(opt_config.w_vars[(periodo, ute.nome, etapa_s)])
                        end
                    end
                end
            end
        end

        # -------------------------
        # Hidros (gh, turb, uch, vert, vf)
        # -------------------------
        if reg.existe_hid > 0
            for uhe in reg.lista_uhes
                unidades_uhe = reg.mapaUHEunidades[uhe.nome]
                for unidade in unidades_uhe
                    conj = reg.mapaUnidadeConjunto[unidade].codigo

                    saida.gh_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)] =
                        value(opt_config.gh_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)])

                    saida.turb_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)] =
                        value(opt_config.turb_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)])

                    # uch existe em todas as etapas no seu modelo novo, então podemos sempre extrair
                    if haskey(opt_config.uch_vars, (periodo, uhe.nome, conj, unidade.codigo, etapa_s))
                        saida.uch_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)] =
                            value(opt_config.uch_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)])
                    end
                end

                saida.vert_vars[(periodo, uhe.nome, etapa_s)] =
                    value(opt_config.vert_vars[(periodo, uhe.nome, etapa_s)])

                saida.vf_vars[(periodo, uhe.nome, etapa_s)] =
                    value(opt_config.vf_vars[(periodo, uhe.nome, etapa_s)])
            end
        end

        # -------------------------
        # Déficit (por submercado)
        # -------------------------
        if caso.Defs == 1
            for sbm in reg.lista_submercados
                saida.deficit_vars[(periodo, sbm.nome, etapa_s)] =
                    value(opt_config.deficit_vars[(periodo, sbm.nome, etapa_s)])
            end
        end

        # -------------------------
        # Intercâmbios
        # -------------------------
        for sbm in reg.lista_submercados
            for sbm2 in reg.lista_submercados
                if sbm.codigo != sbm2.codigo
                    saida.intercambio_vars[(periodo, sbm.nome, sbm2.nome, etapa_s)] =
                        value(opt_config.intercambio_vars[(periodo, sbm.nome, sbm2.nome, etapa_s)])
                end
            end
        end
    end

    return saida
end