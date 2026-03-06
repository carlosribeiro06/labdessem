using CSV
using DataFrames
using Dates
using Logging
using DataStructures: OrderedDict

import ..Data: CaseData,
              SubmercadoConfigData,
              UHEConfigData,
              CONJ_MAQConfig,
              UnidadeHidreletricaConfig,
              UTEConfigData,
              EOLConfigData

"""
    load_registry(case_dir::AbstractString, caso::CaseData)

Lê os arquivos de `CADASTRO/` e constrói:

- DataFrames lidos (`Entrada_*`)
- listas: `lista_submercados`, `lista_uhes`, `lista_unidades`, `lista_utes`, `lista_eols`
- mapas auxiliares (OrderedDict/Dict), incluindo relacionamentos UHE<->unidades
- cadastros por submercado
- `vetor_horario` quando `caso.n_periodos <= 48` (mesma lógica do original)
- flags de existência: `existe_term`, `existe_hid`, `existe_eol`

Retorna um `NamedTuple` com todos os objetos construídos.

"""
function load_registry(case_dir::AbstractString, caso::CaseData)
    cadastro_dir = joinpath(case_dir, "CADASTRO")
    @info "Carregando registry (CADASTRO)" dir=cadastro_dir

    # --------------------------------------------------------------------------
    # 1) Leitura dos CSVs
    # --------------------------------------------------------------------------
    Entrada_EOL          = CSV.read(joinpath(cadastro_dir, "CADASTRO_EOL.csv"), DataFrame)
    Entrada_UTE          = CSV.read(joinpath(cadastro_dir, "CADASTRO_UTE.csv"), DataFrame)
    Entrada_RAMPAS_UP    = CSV.read(joinpath(cadastro_dir, "RAMPAS_UP.csv"), DataFrame)
    Entrada_RAMPAS_DOWN  = CSV.read(joinpath(cadastro_dir, "RAMPAS_DOWN.csv"), DataFrame)
    Entrada_UHE          = CSV.read(joinpath(cadastro_dir, "CADASTRO_UHE.csv"), DataFrame)
    Entrada_UNIDADES_UHE = CSV.read(joinpath(cadastro_dir, "CADASTRO_CONJ_UHE.csv"), DataFrame)
    Entrada_submercados  = CSV.read(joinpath(cadastro_dir, "CADASTRO_SBM.csv"), DataFrame)

    # --------------------------------------------------------------------------
    # 2) Submercados
    # --------------------------------------------------------------------------
    mapa_nome_SBM = OrderedDict()
    mapa_codigo_SBM = OrderedDict()

    cadastroUsinasUnidadesHidreletricasSubmercado = OrderedDict()
    cadastroUsinasTermicasSubmercado = OrderedDict()
    cadastroUsinasEolicasSubmercado = OrderedDict()

    lista_submercados = []
    for sub in eachrow(Entrada_submercados)
        submercado = SubmercadoConfigData()
        submercado.nome = sub.nome
        submercado.codigo = sub.codigo

        push!(lista_submercados, submercado)
        mapa_nome_SBM[sub.nome] = submercado
        mapa_codigo_SBM[sub.codigo] = submercado

        cadastroUsinasUnidadesHidreletricasSubmercado[sub.codigo] = []
        cadastroUsinasTermicasSubmercado[sub.codigo] = []
        cadastroUsinasEolicasSubmercado[sub.codigo] = []
    end

    # --------------------------------------------------------------------------
    # 3) UHEs
    # --------------------------------------------------------------------------
    lista_uhes = []
    mapaCodigoUHE = Dict()
    mapaNomeUHE = Dict()

    for uhe in eachrow(Entrada_UHE)
        usina = UHEConfigData()
        usina.nome = uhe.nome
        usina.codigo = uhe.codigo
        usina.vini = uhe.volume_inicial
        usina.vmin = uhe.vmin
        usina.vmax = uhe.vmax
        usina.tipo = uhe.tipo

        if uhe.jusante === missing
            usina.jusante = ""
        else
            usina.jusante = string(uhe.jusante)
        end

        usina.posto = uhe.posto

        push!(lista_uhes, usina)
        mapaCodigoUHE[usina.codigo] = usina
        mapaNomeUHE[usina.nome] = usina
    end

    # --------------------------------------------------------------------------
    # 4) Unidades e conjuntos por UHE
    # --------------------------------------------------------------------------
    mapaUnidadeConjunto = Dict()
    mapaUnidadeGH = Dict()
    mapaConjuntoGH = Dict()
    mapaUHEunidades = Dict()
    mapa_unidade_sbm = Dict()
    lista_unidades = []

    for uhe in lista_uhes
        dataFrame_UHE_conj_unidades = filter(row -> row.codigo == uhe.codigo, Entrada_UNIDADES_UHE)
        conjuntosDiferentes = unique(dataFrame_UHE_conj_unidades.conjunto_maquinas)
        quantidadeConjuntosUsina = length(conjuntosDiferentes)  # mantido (mesmo se não usado)

        lista_conjuntos = []
        lista_unidades_UHE = []

        for conjunto_val in conjuntosDiferentes
            dataFrame_conj_unidades = filter(row -> row.conjunto_maquinas == conjunto_val, dataFrame_UHE_conj_unidades)

            conjunto = CONJ_MAQConfig()
            conjunto.codigo = conjunto_val

            lista_unidades_conjunto = []

            for row in eachrow(dataFrame_conj_unidades)
                unidade = UnidadeHidreletricaConfig()
                unidade.nome = row.nome
                unidade.codigo = row.unidade_geradora
                unidade.pmin = row.pmin
                unidade.pmax = row.pmax
                unidade.ton = row.Ton
                unidade.toff = row.Toff
                unidade.stat_ini = row.status_inicial
                unidade.ton_toff_ini = row.ton_toff_inicial
                unidade.barra = row.barra
                unidade.submercado = row.submercado
                unidade.turb_max = row.turbinamento_maximo
                unidade.produtibilidade = row.produtibilidade

                push!(lista_unidades_conjunto, unidade)
                push!(lista_unidades_UHE, unidade)
                push!(lista_unidades, unidade)

                push!(cadastroUsinasUnidadesHidreletricasSubmercado[unidade.submercado], unidade)

                mapa_unidade_sbm[unidade] = row.submercado
                mapaUnidadeConjunto[unidade] = conjunto
                mapaUnidadeGH[unidade] = uhe
            end

            conjunto.unidades = lista_unidades_conjunto
            mapaConjuntoGH[conjunto] = uhe
            push!(lista_conjuntos, conjunto)
        end

        uhe.conjunto = lista_conjuntos
        mapaUHEunidades[uhe.nome] = lista_unidades_UHE
    end

    # --------------------------------------------------------------------------
    # 5) Mapa de montantes (usinas a montante)
    # --------------------------------------------------------------------------
    mapa_montantesUsina = Dict{String, Array{String, 1}}()
    for uhe in lista_uhes
        if !haskey(mapa_montantesUsina, uhe.nome)
            mapa_montantesUsina[uhe.nome] = String[]
        end
        for candidata_montante in lista_uhes
            if uhe.nome == candidata_montante.jusante
                push!(mapa_montantesUsina[uhe.nome], candidata_montante.nome)
            end
        end
    end

    # --------------------------------------------------------------------------
    # 6) UTEs + rampas UP/DOWN
    # --------------------------------------------------------------------------
    mapa_ute_sbm = OrderedDict()
    lista_utes = []

    for usi in eachrow(Entrada_UTE)
        usina = UTEConfigData()
        local acionamento = []
        local desligamento = []

        for (nome, rampa) in pairs(eachcol(Entrada_RAMPAS_UP))
            if usi["nome"] == String(nome)
                acionamento = collect(skipmissing(rampa))
            end
        end

        for (nome, rampa) in pairs(eachcol(Entrada_RAMPAS_DOWN))
            if usi["nome"] == String(nome)
                desligamento = collect(skipmissing(rampa))
            end
        end

        usina.nome = usi.nome
        usina.pmin = usi.pmin
        usina.pmax = usi.pmax
        usina.custo = usi.custo
        usina.barra = usi.barra
        usina.codigo = usi.codigo
        usina.ton = usi.Ton
        usina.toff = usi.Toff
        usina.stat_ini = usi.Status_inicial
        usina.ton_toff_ini = usi["ton/toff_inicial"]
        usina.submercado = usi.Submercado
        usina.acionamento = acionamento
        usina.desligamento = desligamento

        push!(cadastroUsinasTermicasSubmercado[usi.Submercado], usina)
        mapa_ute_sbm[usina] = usi["Submercado"]
        push!(lista_utes, usina)
    end

    # --------------------------------------------------------------------------
    # 7) Eólicas
    # --------------------------------------------------------------------------
    mapa_eol_sbm = OrderedDict()
    lista_eols = []

    for eol in eachrow(Entrada_EOL)
        eolica = EOLConfigData()
        eolica.nome = eol.nome
        eolica.posto = eol.posto
        eolica.barra = eol.barra
        eolica.submercado = eol.submercado

        push!(cadastroUsinasEolicasSubmercado[eol.submercado], eolica)
        mapa_eol_sbm[eolica] = eol.submercado
        push!(lista_eols, eolica)
    end

    # --------------------------------------------------------------------------
    # 8) Vetor horário
    # --------------------------------------------------------------------------
    vetor_horario = nothing
    if caso.n_periodos <= 48
        function gerar_vetor_horario(dt_horas::Real, horizonte_horas::Real)
            t0 = Time(0, 0)  # início do dia
            passos = Int(floor(horizonte_horas / dt_horas)) + 1
            vetor = [
                t0 + Hour(floor(Int, dt_horas * i)) +
                Minute(Int(round(60 * (dt_horas * i - floor(dt_horas * i)))))
                for i in 0:(passos - 1)
            ]
            return vetor
        end

        vetor = gerar_vetor_horario(0.5, 24)
        vetor_horario = [Dates.format(t, "HH:MM") for t in vetor]
    end

    # --------------------------------------------------------------------------
    # 9) Flags de existência
    # --------------------------------------------------------------------------
    existe_term = length(lista_utes)
    existe_hid  = length(lista_uhes)
    existe_eol  = length(lista_eols)

    @info "Registry carregado" n_submercados=length(lista_submercados) n_uhes=length(lista_uhes) n_utes=length(lista_utes) n_eols=length(lista_eols)

    return (;
        # DataFrames lidos
        Entrada_EOL,
        Entrada_UTE,
        Entrada_RAMPAS_UP,
        Entrada_RAMPAS_DOWN,
        Entrada_UHE,
        Entrada_UNIDADES_UHE,
        Entrada_submercados,

        # Listas principais
        lista_submercados,
        lista_uhes,
        lista_unidades,
        lista_utes,
        lista_eols,

        # Cadastros por submercado
        cadastroUsinasUnidadesHidreletricasSubmercado,
        cadastroUsinasTermicasSubmercado,
        cadastroUsinasEolicasSubmercado,

        # Mapas auxiliares
        mapa_nome_SBM,
        mapa_codigo_SBM,
        mapaCodigoUHE,
        mapaNomeUHE,
        mapaUnidadeConjunto,
        mapaUnidadeGH,
        mapaConjuntoGH,
        mapaUHEunidades,
        mapa_unidade_sbm,
        mapa_montantesUsina,
        mapa_ute_sbm,
        mapa_eol_sbm,

        # Extras
        vetor_horario,
        existe_term,
        existe_hid,
        existe_eol,
    )
end