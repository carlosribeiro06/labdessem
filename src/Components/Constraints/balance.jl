using JuMP

"""
    add_balance_constraints!(model, opt_config, periodo, etapa, case_config, registry)

Adiciona o balanço de demanda por submercado para um período.

- soma geração térmica no submercado
- soma geração eólica no submercado
- soma geração hídrica no submercado
- adiciona intercâmbios (entradas - saídas)
- adiciona déficit (se habilitado)
- iguala à demanda do submercado no período

Armazena a referência da restrição em:
`opt_config.constraint_balancDem_dict[(periodo, sbm.nome, etapa)]`
"""
function add_balance_constraints!(
    model::JuMP.Model,
    opt_config,
    periodo::Integer,
    etapa::AbstractString,
    case_config,
    registry,
)
    etapa_s = String(etapa)
    caso = case_config.caso

    lista_submercados = registry.lista_submercados

    existe_term = registry.existe_term
    existe_eol  = registry.existe_eol
    existe_hid  = registry.existe_hid

    cad_term_sbm = registry.cadastroUsinasTermicasSubmercado
    cad_eol_sbm  = registry.cadastroUsinasEolicasSubmercado
    cad_hid_sbm  = registry.cadastroUsinasUnidadesHidreletricasSubmercado

    mapaUnidadeGH = registry.mapaUnidadeGH
    mapaUnidadeConjunto = registry.mapaUnidadeConjunto

    for sbm in lista_submercados
        # -------------------------
        # Geração térmica no SBM
        # -------------------------
        geracao_termica = 0
        if existe_term > 0
            if !isempty(cad_term_sbm[sbm.codigo])
                geracao_termica = sum(
                    opt_config.gt_vars[(periodo, term.nome, etapa_s)]
                    for term in cad_term_sbm[sbm.codigo]
                )
            end
        end

        # -------------------------
        # Geração eólica no SBM
        # -------------------------
        geracao_eolica = 0
        if existe_eol > 0
            if !isempty(cad_eol_sbm[sbm.codigo])
                geracao_eolica = sum(
                    opt_config.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)]
                    for eol in cad_eol_sbm[sbm.codigo]
                )
            end
        end

        # -------------------------
        # Geração hídrica no SBM
        # -------------------------
        geracao_hid = 0
        if existe_hid > 0
            if !isempty(cad_hid_sbm[sbm.codigo])
                geracao_hid = sum(
                    opt_config.gh_vars[(periodo,
                                        mapaUnidadeGH[unidade].nome,
                                        mapaUnidadeConjunto[unidade].codigo,
                                        unidade.codigo,
                                        etapa_s)]
                    for unidade in cad_hid_sbm[sbm.codigo]
                )
            end
        end

        # -------------------------
        # Déficit
        # -------------------------
        deficits = (caso.Defs == 1) ? opt_config.deficit_vars[(periodo, sbm.nome, etapa_s)] : 0

        # -------------------------
        # Intercâmbio (entradas - saídas)
        # -------------------------
        inter_in = sum(
            opt_config.intercambio_vars[(periodo, sbm_2.nome, sbm.nome, etapa_s)]
            for sbm_2 in lista_submercados if sbm != sbm_2;
            init = 0.0
        )

        inter_out = sum(
            opt_config.intercambio_vars[(periodo, sbm.nome, sbm_2.nome, etapa_s)]
            for sbm_2 in lista_submercados if sbm != sbm_2;
            init = 0.0
        )

        # -------------------------
        # Balanço de demanda
        # -------------------------
        opt_config.constraint_balancDem_dict[(periodo, sbm.nome, etapa_s)] = @constraint(
            model,
            geracao_termica + geracao_hid + geracao_eolica
            + inter_in
            - inter_out
            + deficits
            == sbm.demanda[periodo]
        )
    end

    return nothing
end