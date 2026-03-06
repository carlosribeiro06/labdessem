using CSV
using DataFrames
using Logging

import ..Data: CaseData, FPHA, Info_Linhas, Info_Barras, Alphas

"""
    load_operation_data(case_dir::AbstractString, caso::CaseData, registry)

Carrega os dados referentes à operação (pasta `OPERACAO/`) e retorna um `NamedTuple` contendo:

- DataFrames lidos (Dat_horas, Dbar, DCarga, D_OPER_SBM, dat_vaz, dat_eol, dat_interc, ...)
- `lista_fpha`, `lista_linhas`, `lista_barras`
- `Num_BAR`, `Num_LIN`, `mapa_periodo_hora`
- `alpha` quando `caso.Cortes == 1` (com `alpha.cortes = unique(dat_fcf.corte)`)
- Atualiza `caso.n_periodos` com `Dat_horas.PERIODO[end]`
- Atualiza `sbm.demanda` e `sbm.deficit_cost` nos submercados do `registry`
"""
function load_operation_data(case_dir::AbstractString, caso::CaseData, registry)
    oper_dir = joinpath(case_dir, "OPERACAO")
    @info "Carregando dados de operação (OPERACAO)" dir=oper_dir

    # --------------------------------------------------------------------------
    # 1) Leitura dos CSVs
    # --------------------------------------------------------------------------
    Dat_horas = CSV.read(joinpath(oper_dir, "OPER_DURACAO.csv"), DataFrame)
    caso.n_periodos = Dat_horas.PERIODO[end]  # mantido: atualiza n_periodos

    Dbar = CSV.read(joinpath(oper_dir, "INFO_LINHA.csv"), DataFrame)
    DCarga = CSV.read(joinpath(oper_dir, "INFO_CARGA_BARRA.csv"), DataFrame)
    D_OPER_SBM = CSV.read(joinpath(oper_dir, "OPER_SBM.csv"), DataFrame)

    dat_vaz = CSV.read(joinpath(oper_dir, "vazao.csv"), DataFrame)
    dat_eol = CSV.read(joinpath(oper_dir, "eol.csv"), DataFrame)

    dat_interc = CSV.read(joinpath(oper_dir, "restr_limite_intercambio.csv"), DataFrame)
    dat_interc_tabela = CSV.read(joinpath(oper_dir, "restr_limite_intercambio_tabela.csv"), DataFrame)
    dat_interc_tabela_valores = CSV.read(joinpath(oper_dir, "restr_limite_intercambio_tabela_valores.csv"), DataFrame)

    dat_fcf = CSV.read(joinpath(oper_dir, "cortes_FCF.csv"), DataFrame)
    dat_fpha = CSV.read(joinpath(oper_dir, "OPER_FPHA.csv"), DataFrame)

    # --------------------------------------------------------------------------
    # 2) FPHA
    # --------------------------------------------------------------------------
    lista_uhes = registry.lista_uhes
    lista_fpha = []

    for uhe in lista_uhes
        dataFrameFPHA = filter(corte -> corte.Nome == uhe.nome, dat_fpha)

        corte_fpha = FPHA()

        for corte in eachrow(dataFrameFPHA)
            corte_fpha.usina = corte.Nome
            corte_fpha.corte = corte.SegFPHA
            corte_fpha.RHS = corte.Rhs
            corte_fpha.Fcorrec = corte.Fcorrec
            corte_fpha.Varm_coef = corte.Varm
            corte_fpha.Qtur_coef = corte.Qtur
            corte_fpha.Qlat_coef = corte.Qlat
            push!(lista_fpha, corte_fpha)
        end
    end

    # --------------------------------------------------------------------------
    # 3) Demanda e custo de déficit por submercado
    # --------------------------------------------------------------------------
    lista_submercados = registry.lista_submercados
    for sbm in lista_submercados
        dataFrameSbm = filter(submercado -> submercado.codigo == sbm.codigo, D_OPER_SBM)
        sbm.demanda = dataFrameSbm.demanda
        sbm.deficit_cost = dataFrameSbm.custo_deficit[1]
    end

    # --------------------------------------------------------------------------
    # 4) Linhas
    # --------------------------------------------------------------------------
    lista_linhas = []
    for lin in eachrow(Dbar)
        linha = Info_Linhas()
        linha.codigo = lin["codigo"]
        linha.barra_de = lin["barra_de"]
        linha.barra_para = lin["barra_para"]
        linha.reatancia = lin["reatancia"]
        linha.capacidade = lin["capacidade"]
        push!(lista_linhas, linha)
    end

    # --------------------------------------------------------------------------
    # 5) Barras
    # --------------------------------------------------------------------------
    lista_barras = []
    for barra in eachrow(DCarga)
        bar = Info_Barras()
        bar.codigo = barra.codigo
        bar.nome = barra.nome
        bar.carga = barra.carga
        bar.submercado = barra.submercado
        bar.periodo = barra.periodo
        push!(lista_barras, bar)
    end

    Num_BAR = length(DCarga[DCarga.periodo .== 1, :carga])
    Num_LIN = length(lista_linhas)

    # --------------------------------------------------------------------------
    # 6) Mapa período -> horas
    # --------------------------------------------------------------------------
    mapa_periodo_hora = Dict()
    for hora in eachrow(Dat_horas)
        mapa_periodo_hora[hora.PERIODO] = hora.HORAS
    end

    # --------------------------------------------------------------------------
    # 7) Cortes (alpha)
    # --------------------------------------------------------------------------
    alpha = nothing
    if caso.Cortes == 1
        alpha = Alphas()
        alpha.cortes = unique(dat_fcf.corte)
    end

    @info "Dados de operação carregados" n_periodos=caso.n_periodos n_linhas=Num_LIN n_barras=Num_BAR n_fpha=length(lista_fpha)

    return (;
        Dat_horas,
        Dbar,
        DCarga,
        D_OPER_SBM,
        dat_vaz,
        dat_eol,
        dat_interc,
        dat_interc_tabela,
        dat_interc_tabela_valores,
        dat_fcf,
        dat_fpha,
        lista_fpha,
        lista_linhas,
        lista_barras,
        Num_BAR,
        Num_LIN,
        mapa_periodo_hora,
        alpha,
    )
end