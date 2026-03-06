using JuMP
using DataFrames

"""
    add_fpha_constraints!(model, opt_config, periodo, etapa, case_config, registry, operation)

Adiciona as restrições FPHA para um período.

Lógica mantida do original:
- Se `aciona_fpha == 1`:
  Para cada UHE:
    - obtém unidades da usina
    - filtra `dat_fpha` por Nome da usina
    - calcula `varm` (média de volumes: (vf[t]+vini)/2 no t=1, senão (vf[t]+vf[t-1])/2)
    - monta somatórios de geração e turbinamento
    - para cada corte da FPHA:
        sum(gh) <= Fcorrec * (varm*Varm + sum(turb)*Qtur + vert*Qlat + Rhs)
"""
function add_fpha_constraints!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
    operation,
)
    etapa_s = String(etapa)
    aciona_fpha = case_config.aciona_fpha

    if aciona_fpha == 1
        dat_fpha = operation.dat_fpha

        for uhe in registry.lista_uhes
            unidades_uhe = registry.mapaUHEunidades[uhe.nome]
            dataFrameFPHA = filter(row -> row.Nome == uhe.nome, dat_fpha)

            somatorio_geracao = Any[]
            somatorio_turbinamento = Any[]

            varm = 0
            if periodo == 1
                varm = (opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] + uhe.vini) / 2
            else
                varm = (opt_config.vf_vars[(periodo, uhe.nome, etapa_s)] + opt_config.vf_vars[(periodo - 1, uhe.nome, etapa_s)]) / 2
            end

            for unidade in unidades_uhe
                conj_codigo = registry.mapaUnidadeConjunto[unidade].codigo

                push!(
                    somatorio_geracao,
                    opt_config.gh_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)]
                )

                push!(
                    somatorio_turbinamento,
                    opt_config.turb_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)]
                )
            end

            for corte in eachrow(dataFrameFPHA)
                @constraint(
                    model,
                    sum(somatorio_geracao) <=
                    corte.Fcorrec * (
                        varm * corte.Varm +
                        sum(somatorio_turbinamento) * corte.Qtur +
                        opt_config.vert_vars[(periodo, uhe.nome, etapa_s)] * corte.Qlat +
                        corte.Rhs
                    )
                )
            end
        end
    end

    return nothing
end