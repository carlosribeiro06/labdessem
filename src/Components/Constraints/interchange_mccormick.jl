using JuMP

"""
    add_interchange_mccormick_constraints!(model, opt_config, etapa, case_config, registry, operation)

Adiciona restrições do envelope McCormick para limites de intercâmbio.

Lógica mantida do original:
- Se caso.Rest_Inter_Tabela == 1:
  - cria variáveis binárias uint (uma lista por período e submercado, baseada em dat_interc_tabela)
  - combina uints de dois submercados (produto cartesiano) em lista_uints_comb por período
  - cria variáveis wint por período (uma por combinação)
  - adiciona restrições de McCormick para wint
  - impõe sum(wint) == 1 por período
  - impõe intercâmbio <= soma(wint .* valores_tabela)
  - impõe geração (hid + term) dentro dos limites (LINF, LSUP) ponderados pelos uints

Entradas esperadas:
- case_config: NamedTuple com `caso`
- registry: NamedTuple com listas e cadastros por submercado e mapas
- operation: NamedTuple com `dat_interc_tabela` e `dat_interc_tabela_valores`
"""
function add_interchange_mccormick_constraints!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
    registry,
    operation,
)
    etapa_s = String(etapa)
    caso = case_config.caso

    if caso.Rest_Inter_Tabela != 1
        return nothing
    end

    lista_submercados = registry.lista_submercados
    dat_interc_tabela = operation.dat_interc_tabela
    dat_interc_tabela_valores = operation.dat_interc_tabela_valores

    existe_term = registry.existe_term
    existe_hid  = registry.existe_hid

    cad_term_sbm = registry.cadastroUsinasTermicasSubmercado
    cad_hid_sbm  = registry.cadastroUsinasUnidadesHidreletricasSubmercado

    mapaUnidadeGH = registry.mapaUnidadeGH
    mapaUnidadeConjunto = registry.mapaUnidadeConjunto

    # --------------------------------------------------------------------------
    # 1) Estruturas auxiliares
    # --------------------------------------------------------------------------
    lista_uints_comb = Dict()
    lista_uints = Dict()
    lista_wints = Dict()

    # inicializa lista_uints[(periodo, sbm.codigo, etapa)] = []
    for periodo in 1:caso.n_periodos
        for sbm in lista_submercados
            lista_uints[(periodo, sbm.codigo, etapa_s)] = []
        end
    end

    # --------------------------------------------------------------------------
    # 2) Cria uint (binárias) por período e submercado, baseado na tabela
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        for sbm in lista_submercados
            dataFrame_tabela = filter(row -> row.SUBMERCADO == sbm.codigo, dat_interc_tabela)
            for num in 1:size(dataFrame_tabela, 1)
                opt_config.uint[(periodo, sbm.codigo, num, etapa_s)] =
                    @variable(model, base_name = "uint_$(periodo)_$(sbm.codigo)_$(num)_$(etapa_s),", binary = true)

                push!(lista_uints[(periodo, sbm.codigo, etapa_s)], opt_config.uint[(periodo, sbm.codigo, num, etapa_s)])
            end
        end
    end

    # --------------------------------------------------------------------------
    # 3) Combinações (produto cartesiano) de uints entre dois submercados
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        for sbm in lista_submercados
            for sbm2 in lista_submercados
                if sbm != sbm2
                    lista_uints_comb[periodo] = collect(Iterators.product(
                        lista_uints[(periodo, sbm.codigo, etapa_s)],
                        lista_uints[(periodo, sbm2.codigo, etapa_s)]
                    ))
                    lista_uints_comb[periodo] = collect(vec(lista_uints_comb[periodo]))
                end
            end
        end
    end

    # --------------------------------------------------------------------------
    # 4) Inicializa lista_wints por período e cria variáveis wint
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        lista_wints[periodo] = []
        for num in 1:length(lista_uints_comb[periodo])
            opt_config.wint[(periodo, num, etapa_s)] =
                @variable(model, base_name = "wint_$(periodo)_$(num)_$(etapa_s)")
            push!(lista_wints[periodo], opt_config.wint[(periodo, num, etapa_s)])
        end
    end

    # --------------------------------------------------------------------------
    # 5) Restrições de McCormick para wint
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        for num in 1:length(lista_uints_comb[periodo])
            @constraint(model, opt_config.wint[(periodo, num, etapa_s)] >= 0)
            @constraint(model, opt_config.wint[(periodo, num, etapa_s)] >= sum(lista_uints_comb[periodo][num]) - 1)
            @constraint(model, opt_config.wint[(periodo, num, etapa_s)] <= lista_uints_comb[periodo][num][1])
            @constraint(model, opt_config.wint[(periodo, num, etapa_s)] <= lista_uints_comb[periodo][num][2])
        end
    end

    # --------------------------------------------------------------------------
    # 6) Soma dos wint deve ser 1 por período
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        temp = Any[]
        for num in 1:length(lista_uints_comb[periodo])
            push!(temp, opt_config.wint[(periodo, num, etapa_s)])
        end
        @constraint(model, sum(temp) == 1)
    end

    # --------------------------------------------------------------------------
    # 7) Limite de intercâmbio via wint .* valores
    # --------------------------------------------------------------------------
    valores = Vector(dat_interc_tabela_valores.VALOR)

    for periodo in 1:caso.n_periodos
        for sbm in lista_submercados
            for sbm2 in lista_submercados
                if sbm != sbm2
                    @constraint(
                        model,
                        opt_config.intercambio_vars[(periodo, sbm.nome, sbm2.nome, etapa_s)] <=
                        sum(Vector(lista_wints[periodo]) .* valores)
                    )
                end
            end
        end
    end

    # --------------------------------------------------------------------------
    # 8) Restrições de geração (hid + term) dentro das faixas (LINF/LSUP)
    # --------------------------------------------------------------------------
    for periodo in 1:caso.n_periodos
        for sbm in lista_submercados
            dataFrame_tabela = filter(row -> row.SUBMERCADO == sbm.codigo, dat_interc_tabela)

            geracao_termica = 0
            if existe_term > 0
                if !isempty(cad_term_sbm[sbm.codigo])
                    geracao_termica = sum(
                        opt_config.gt_vars[(periodo, term.nome, etapa_s)]
                        for term in cad_term_sbm[sbm.codigo]
                    )
                end
            end

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

            @constraint(
                model,
                geracao_hid + geracao_termica >=
                sum(Vector(lista_uints[(periodo, sbm.codigo, etapa_s)]) .* Vector(dataFrame_tabela.LINF))
            )
            @constraint(
                model,
                geracao_hid + geracao_termica <=
                sum(Vector(lista_uints[(periodo, sbm.codigo, etapa_s)]) .* Vector(dataFrame_tabela.LSUP))
            )
        end
    end

    return nothing
end