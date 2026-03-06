using JuMP

"""
    add_hydro_variables!(model, opt_config, periodo, etapa, case_config, registry)

Cria as variáveis associadas às hidrelétricas.

Lógica (mantida do original):
- Se existe_hid > 0:
  - para cada uhe:
      - para cada unidade em mapaUHEunidades[uhe.nome]:
          turb_vars[...] = @variable(...)
          gh_vars[...]   = @variable(...)
          uch_vars[...]  = @variable(...) com:
              - etapa == "MILP": binária se aciona_uch==1, contínua se aciona_uch==0
              - etapa == "PL_int_fix": contínua
              - etapa == "PL": contínua
      - vert_vars[(periodo,uhe.nome,etapa)] = @variable(...)
      - vf_vars[(periodo,uhe.nome,etapa)]   = @variable(...)

Entradas esperadas:
- `case_config`: NamedTuple com `aciona_uch`
- `registry`: NamedTuple com `existe_hid`, `lista_uhes`, `mapaUHEunidades`, `mapaUnidadeConjunto`
"""
function add_hydro_variables!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    existe_hid = registry.existe_hid
    aciona_uch = case_config.aciona_uch

    if existe_hid > 0
        for uhe in registry.lista_uhes
            unidades_uhe = registry.mapaUHEunidades[uhe.nome]

            for unidade in unidades_uhe
                conj_codigo = registry.mapaUnidadeConjunto[unidade].codigo

                opt_config.turb_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                    @variable(model, base_name = "turb_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)")

                opt_config.gh_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                    @variable(model, base_name = "gh_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)")

                if etapa_s == "MILP"
                    if aciona_uch == 1
                        opt_config.uch_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                            @variable(model, base_name = "uch_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)", binary = true)
                    end
                    if aciona_uch == 0
                        opt_config.uch_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                            @variable(model, base_name = "uch_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)")
                    end
                end

                if etapa_s == "PL_int_fix"
                    opt_config.uch_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                        @variable(model, base_name = "uch_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)")
                end

                if etapa_s == "PL"
                    opt_config.uch_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)] =
                        @variable(model, base_name = "uch_$(periodo)_$(uhe.codigo)_$(conj_codigo)_$(unidade.codigo)_$(etapa_s)")
                end
            end

            opt_config.vert_vars[(periodo, uhe.nome, etapa_s)] =
                @variable(model, base_name = "vert_$(periodo)_$(uhe.codigo)_$(etapa_s)")

            opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] =
                @variable(model, base_name = "vf_$(periodo)_$(uhe.codigo)_$(etapa_s)")
        end
    end

    return nothing
end