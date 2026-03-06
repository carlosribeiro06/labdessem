using JuMP

"""
    add_interchange_limits_constraints!(model, opt_config, periodo, etapa, case_config, registry, operation)

Adiciona restrições de limite de intercâmbio entre submercados para um período.

Lógica (mantida do original):
- Se `caso.Rest_Inter == 1`:
  Para cada par de submercados distintos (sbm, sbm_2):
    limite_intercambio = dat_interc[(SUBMERCADO1==sbm.codigo) & (SUBMERCADO2==sbm_2.codigo), "VALOR"][1]
    intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa)] <= limite_intercambio

Entradas esperadas:
- `case_config`: NamedTuple contendo `caso`
- `registry`: NamedTuple contendo `lista_submercados`
- `operation`: NamedTuple contendo `dat_interc` (DataFrame)
"""
function add_interchange_limits_constraints!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
    operation,
)
    etapa_s = String(etapa)
    caso = case_config.caso
    lista_submercados = registry.lista_submercados
    dat_interc = operation.dat_interc

    if caso.Rest_Inter == 1
        for sbm in lista_submercados
            for sbm_2 in lista_submercados
                if sbm.codigo != sbm_2.codigo
                    limite_intercambio =
                        dat_interc[
                            (dat_interc.SUBMERCADO1 .== sbm.codigo) .&
                            (dat_interc.SUBMERCADO2 .== sbm_2.codigo),
                            "VALOR"
                        ][1]

                    @constraint(
                        model,
                        opt_config.intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa_s)] <= limite_intercambio
                    )
                end
            end
        end
    end

    return nothing
end