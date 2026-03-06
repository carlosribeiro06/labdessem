using JuMP

import ..Data: OtimizacaoConfig

"""
    objective_expression(opt_config::OtimizacaoConfig, etapa::AbstractString, case_config, registry; pi_demanda::Real=1000)

Retorna a expressão da Função Objetivo (FOB) para uso em `@objective`.

Parâmetros:
- `opt_config`: estrutura com dicionários de variáveis JuMP (gt_vars, y_vars, vert_vars, etc.)
- `etapa`: "MILP", "PL", "PL_int_fix", etc. (mesma convenção do seu código)
- `case_config`: NamedTuple retornado por `read_case_config` ou `load_case(...).config`
  (precisa ter `caso`, `trata_ton`, `aciona_uct`, ...)
- `registry`: NamedTuple retornado por `load_registry` ou `load_case(...).registry`
  (precisa ter `lista_utes`, `lista_uhes`, `lista_submercados`, `existe_term`, `existe_hid`)

Keyword:
- `pi_demanda`: penalização usada no cálculo de `cvu_pi` (default 1000)

Matemática:
-  custo_termico + penal_vert + penal_inter + custo_defs + alpha + parcela_ton
"""
function objective_expression(
    opt_config::OtimizacaoConfig,
    etapa::AbstractString,
    case_config,
    registry;
    pi_demanda::Real = 1000,
)
    caso = case_config.caso
    trata_ton = case_config.trata_ton
    aciona_uct = case_config.aciona_uct

    lista_utes = registry.lista_utes
    lista_uhes = registry.lista_uhes
    lista_submercados = registry.lista_submercados
    existe_term = registry.existe_term
    existe_hid = registry.existe_hid

    # Acumuladores
    custo_termico = 0.0
    parcela_ton   = 0.0
    penal_vert    = 0.0
    penal_inter   = 0.0
    custo_defs    = 0.0

    # -------------------------
    # Parcela TON
    # -------------------------
    if trata_ton == 1
        for periodo in 1:caso.n_periodos
            if etapa == "MILP"
                if aciona_uct == 1
                    if existe_term > 0
                        for ute in lista_utes
                            residual = max(ute.ton - (caso.n_periodos - periodo), 0)
                            cvu_pi = max(ute.custo - pi_demanda, 0)
                            parcela_ton += opt_config.y_vars[(periodo, ute.nome, String(etapa))] * (residual * ute.pmin * cvu_pi)
                        end
                    end
                end
            end
        end
    end

    # -------------------------
    # Custo térmico
    # -------------------------
    for periodo in 1:caso.n_periodos
        if existe_term > 0
            custo_termico += sum(ute.custo * opt_config.gt_vars[(periodo, ute.nome, String(etapa))] for ute in lista_utes)
        end
    end

    # -------------------------
    # Penalização vertimento
    # -------------------------
    for periodo in 1:caso.n_periodos
        if existe_hid > 0
            penal_vert += sum(0.01 * opt_config.vert_vars[(periodo, uhe.nome, String(etapa))] for uhe in lista_uhes)
        end
    end

    # -------------------------
    # Penalização intercâmbio
    # -------------------------
    for periodo in 1:caso.n_periodos
        if caso.Rest_Inter == 1
            penal_inter += sum(
                0.01 * opt_config.intercambio_vars[(periodo, sbm.nome, sbm_2.nome, String(etapa))]
                for sbm in lista_submercados, sbm_2 in lista_submercados if sbm != sbm_2;
                init = 0.0
            )
        end
    end

    # -------------------------
    # Déficit
    # -------------------------
    for periodo in 1:caso.n_periodos
        if caso.Defs == 1
            custo_defs += sum(
                sbm.deficit_cost * opt_config.deficit_vars[(periodo, sbm.nome, String(etapa))]
                for sbm in lista_submercados
            )
        end
    end

    # -------------------------
    # FOB final
    # -------------------------
    FOB = custo_termico + penal_vert + penal_inter + custo_defs + opt_config.alpha_vars + parcela_ton

    return FOB
end