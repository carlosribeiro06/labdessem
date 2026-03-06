using JuMP
using DataFrames

"""
    add_hydro_registry_constraints!(model, opt_config, periodo, etapa, case_config, registry, operation)

Adiciona as restrições do cadastro de hidrelétricas.

Lógica:
- Se existe_hid > 0:
  - (Etapa == "PL") adiciona 0 <= uch <= 1
  - Se aciona_uch == 0:
      (Etapa == "MILP" ou "PL_int_fix") adiciona 0 <= uch <= 1
  - Sempre adiciona:
      gh >= uch*pmin
      gh <= uch*pmax
      turb <= uch*turb_max
      turb >= 0
  - Para cada UHE:
      Se aciona_fpha == 0:
         gh == produtibilidade * turb
      vert >= 0
      vf >= 0
      vf <= vmax
      vf >= vmin
      balanço hídrico armazenado em opt_config.constraint_dict[(periodo,uhe.nome,etapa)]

Entradas esperadas:
- `case_config`: NamedTuple (ex.: `load_case(...).config`) contendo `aciona_uch`, `aciona_fpha`
- `registry`: NamedTuple (ex.: `load_case(...).registry`) contendo:
    `lista_uhes`, `existe_hid`, `mapaUHEunidades`, `mapaUnidadeConjunto`, `mapa_montantesUsina`
- `operation`: NamedTuple (ex.: `load_case(...).operation`) contendo `dat_vaz`
"""
function add_hydro_registry_constraints!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
    operation,
)
    etapa_s = String(etapa)
    existe_hid = registry.existe_hid
    aciona_uch = case_config.aciona_uch
    aciona_fpha = case_config.aciona_fpha

    # atalhos
    lista_uhes = registry.lista_uhes
    mapaUHEunidades = registry.mapaUHEunidades
    mapaUnidadeConjunto = registry.mapaUnidadeConjunto
    mapa_montantesUsina = registry.mapa_montantesUsina
    dat_vaz = operation.dat_vaz

    if existe_hid > 0
        # ----------------------------------------------------------------------
        # 1) Limites uch (0..1) dependendo de etapa/acionamento
        # ----------------------------------------------------------------------
        if etapa_s == "PL"
            for uhe in lista_uhes
                for conj in uhe.conjunto
                    for ugh in conj.unidades
                        @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] >= 0)
                        @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] <= 1)
                    end
                end
            end
        end

        if aciona_uch == 0
            if etapa_s == "MILP"
                for uhe in lista_uhes
                    for conj in uhe.conjunto
                        for ugh in conj.unidades
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] >= 0)
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] <= 1)
                        end
                    end
                end
            end

            if etapa_s == "PL_int_fix"
                for uhe in lista_uhes
                    for conj in uhe.conjunto
                        for ugh in conj.unidades
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] >= 0)
                            @constraint(model, opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] <= 1)
                        end
                    end
                end
            end
        end

        # ----------------------------------------------------------------------
        # 2) Limites gh/turb e não-negatividade
        # ----------------------------------------------------------------------
        for uhe in lista_uhes
            for conj in uhe.conjunto
                for ugh in conj.unidades
                    @constraint(model,
                        opt_config.gh_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] >=
                        opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] * ugh.pmin
                    )
                    @constraint(model,
                        opt_config.gh_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] <=
                        opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] * ugh.pmax
                    )
                    @constraint(model,
                        opt_config.turb_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] <=
                        opt_config.uch_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] * ugh.turb_max
                    )
                    @constraint(model, opt_config.turb_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] >= 0)
                end
            end
        end

        # ----------------------------------------------------------------------
        # 3) Para cada UHE: vínculo gh-turb (quando FPHA desligado), bounds vf/vert,
        #    e balanço hídrico
        # ----------------------------------------------------------------------
        for uhe in lista_uhes
            if aciona_fpha == 0
                for conj in uhe.conjunto
                    for ugh in conj.unidades
                        @constraint(model,
                            opt_config.gh_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)] ==
                            ugh.produtibilidade * opt_config.turb_vars[(periodo, uhe.nome, conj.codigo, ugh.codigo, etapa_s)]
                        )
                    end
                end
            end

            @constraint(model, opt_config.vert_vars[(periodo, uhe.nome, etapa_s)] >= 0)
            @constraint(model, opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] >= 0)
            @constraint(model, opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] <= uhe.vmax)
            @constraint(model, opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] >= uhe.vmin)

            unidades_uhe = mapaUHEunidades[uhe.nome]

            # vazão afluente
            vazao_afluente = 0
            if uhe.posto != 999
                vazao_afluente = dat_vaz[(dat_vaz.posto .== uhe.posto) .& (dat_vaz.periodo .== periodo), "afluencia"][1]
            else
                vazao_afluente = 0
            end

            # volume inicial
            if periodo == 1
                Vol_ini = uhe.vini
            else
                Vol_ini = opt_config.vf_vars[(periodo - 1, uhe.nome, etapa_s)]
            end

            converte_m3s_hm3 = 1

            opt_config.constraint_dict[(periodo, uhe.nome, etapa_s)] = @constraint(
                model,
                opt_config.vf_vars[(periodo, uhe.nome, etapa_s)]
                + sum(
                    opt_config.turb_vars[(periodo, uhe.nome, mapaUnidadeConjunto[unidade].codigo, unidade.codigo, etapa_s)] * converte_m3s_hm3
                    for unidade in unidades_uhe
                )
                + opt_config.vert_vars[(periodo, uhe.nome, etapa_s)] * converte_m3s_hm3
                ==
                Vol_ini + (vazao_afluente) * converte_m3s_hm3
                + sum(
                    opt_config.turb_vars[(periodo, nomeUsiMont, mapaUnidadeConjunto[unidade].codigo, unidade.codigo, etapa_s)] * converte_m3s_hm3
                    for nomeUsiMont in mapa_montantesUsina[uhe.nome]
                    for unidade in mapaUHEunidades[nomeUsiMont]
                )
                + sum(
                    opt_config.vert_vars[(periodo, nomeUsiMont, etapa_s)] * converte_m3s_hm3
                    for nomeUsiMont in mapa_montantesUsina[uhe.nome]
                )
            )
        end
    end

    return nothing
end