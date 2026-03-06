using CSV
using DataFrames
using JuMP
using LinearAlgebra

import ..Network

"""
Garante que um subdiretório dentro de `case.out_dir` exista e retorna o caminho.
"""
function _ensure_outdir(case, subdir::AbstractString)
    dir = joinpath(case.out_dir, subdir)
    mkpath(dir)
    return dir
end

# ------------------------------------------------------------------------------
# TÉRMICAS
# ------------------------------------------------------------------------------

"""
    export_ute_csv(case, saida, etapa)

Gera `geracoes_termicas.csv` em `out_termicas_<etapa>/`.
"""
function export_ute_csv(case, saida, etapa::AbstractString)
    etapa_s = String(etapa)
    reg = case.registry
    cfg = case.config

    if reg.existe_term <= 0
        return nothing
    end

    path_output = _ensure_outdir(case, "out_termicas_$(etapa_s)")

    nome_list = String[]
    periodo_list = Int[]
    sbm_list = Any[]
    gts_list = Float64[]
    uts_list = Float64[]
    ys_list = Float64[]
    ws_list = Float64[]

    for periodo in 1:cfg.caso.n_periodos
        for ute in reg.lista_utes
            push!(nome_list, ute.nome)
            push!(periodo_list, periodo)
            push!(sbm_list, reg.mapa_ute_sbm[ute])

            push!(gts_list, saida.gt_vars[(periodo, ute.nome, etapa_s)])
            push!(uts_list, get(saida.uct_vars, (periodo, ute.nome, etapa_s), NaN))

            if cfg.aciona_uct == 1
                push!(ys_list, get(saida.y_vars, (periodo, ute.nome, etapa_s), NaN))
                push!(ws_list, get(saida.w_vars, (periodo, ute.nome, etapa_s), NaN))
            else
                push!(ys_list, NaN)
                push!(ws_list, NaN)
            end
        end
    end

    filepath = joinpath(path_output, "geracoes_termicas.csv")
    df = DataFrame(
        periodo = periodo_list,
        submercado = sbm_list,
        nome = nome_list,
        geracao = gts_list,
        status = uts_list,
        acionamento = ys_list,
        desligamento = ws_list,
    )
    CSV.write(filepath, df)
    return filepath
end

# ------------------------------------------------------------------------------
# EÓLICAS
# ------------------------------------------------------------------------------

"""
    export_eol_csv(case, saida, etapa)

Gera `geracoes_eolicas.csv` em `out_eolicas_<etapa>/`.
"""
function export_eol_csv(case, saida, etapa::AbstractString)
    etapa_s = String(etapa)
    reg = case.registry
    cfg = case.config

    if reg.existe_eol <= 0
        return nothing
    end

    path_output = _ensure_outdir(case, "out_eolicas_$(etapa_s)")

    nome_list = String[]
    posto_list = Int[]
    periodo_list = Int[]
    sbm_list = Any[]
    geols_list = Float64[]

    for periodo in 1:cfg.caso.n_periodos
        for eol in reg.lista_eols
            push!(nome_list, eol.nome)
            push!(posto_list, eol.posto)
            push!(periodo_list, periodo)
            push!(sbm_list, reg.mapa_eol_sbm[eol])
            push!(geols_list, saida.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)])
        end
    end

    filepath = joinpath(path_output, "geracoes_eolicas.csv")
    df = DataFrame(
        periodo = periodo_list,
        submercado = sbm_list,
        posto = posto_list,
        nome = nome_list,
        geracao = geols_list,
    )
    CSV.write(filepath, df)
    return filepath
end

# ------------------------------------------------------------------------------
# HIDRÉTRICAS
# ------------------------------------------------------------------------------

"""
    export_uhe_csv(case, saida, etapa)

Gera:
- `hidreletricas.csv` (volumes/vertimento/turbinamento agregados por usina)
- `ugh.csv` (geração por unidade)
em `out_hidreletricas_<etapa>/`.
"""
function export_uhe_csv(case, saida, etapa::AbstractString)
    etapa_s = String(etapa)
    reg = case.registry
    cfg = case.config

    if reg.existe_hid <= 0
        return nothing
    end

    path_output = _ensure_outdir(case, "out_hidreletricas_$(etapa_s)")

    # -------------------------
    # 1) hidreletricas.csv (volumes / vert / turb agregados)
    # -------------------------
    nome_list = String[]
    periodo_list = Int[]
    verts_list = Any[]
    volfs_list = Any[]
    turbs_list = Any[]

    # período 0 com volume inicial
    for periodo in 0:cfg.caso.n_periodos
        for uhe in reg.lista_uhes
            if periodo == 0
                push!(nome_list, uhe.nome)
                push!(verts_list, "-")
                push!(turbs_list, "-")
                push!(volfs_list, uhe.vini)
            else
                push!(nome_list, uhe.nome)
                push!(verts_list, saida.vert_vars[(periodo, uhe.nome, etapa_s)])
                push!(volfs_list, saida.vf_vars[(periodo, uhe.nome, etapa_s)])
            end
        end
    end

    # turbinamento agregado por usina e período (1..T)
    for periodo in 1:cfg.caso.n_periodos
        for uhe in reg.lista_uhes
            temp = Float64[]
            unidades_uhe = reg.mapaUHEunidades[uhe.nome]
            for unidade in unidades_uhe
                conj = reg.mapaUnidadeConjunto[unidade].codigo
                push!(temp, saida.turb_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)])
            end
            push!(turbs_list, sum(temp))
        end
    end

    # coluna "variavel" (mantém o formato do legado)
    var = String[]
    for _ in volfs_list; push!(var, "volume armazenado"); end
    for _ in verts_list; push!(var, "volume vertido"); end
    for _ in turbs_list; push!(var, "volume turbinado"); end

    for periodo in 0:cfg.caso.n_periodos
        for _ in 1:reg.existe_hid
            push!(periodo_list, periodo)
        end
    end

    filepath1 = joinpath(path_output, "hidreletricas.csv")
    volumes = DataFrame(
        periodo = [periodo_list; periodo_list; periodo_list],
        nome = [nome_list; nome_list; nome_list],
        variavel = var,
        valor = [volfs_list; verts_list; turbs_list],
    )
    CSV.write(filepath1, volumes)

    # -------------------------
    # 2) ugh.csv (geração por unidade)
    # -------------------------
    nome_list2 = String[]
    periodo_list2 = Int[]
    sbm_list2 = Any[]
    ghs_list2 = Float64[]

    for periodo in 1:cfg.caso.n_periodos
        for uhe in reg.lista_uhes
            unidades_uhe = reg.mapaUHEunidades[uhe.nome]
            for unidade in unidades_uhe
                conj = reg.mapaUnidadeConjunto[unidade].codigo
                push!(nome_list2, uhe.nome)
                push!(periodo_list2, periodo)
                push!(sbm_list2, reg.mapa_unidade_sbm[unidade])
                push!(ghs_list2, saida.gh_vars[(periodo, uhe.nome, conj, unidade.codigo, etapa_s)])
            end
        end
    end

    filepath2 = joinpath(path_output, "ugh.csv")
    ugh_df = DataFrame(
        periodo = periodo_list2,
        submercado = sbm_list2,
        nome = nome_list2,
        geracao = ghs_list2,
    )
    CSV.write(filepath2, ugh_df)

    return (filepath1, filepath2)
end

# ------------------------------------------------------------------------------
# CUSTO
# ------------------------------------------------------------------------------

"""
    export_cost_csv(case, saida, opt_config, etapa, tempo_total)

Gera `custo_total_operacao.csv` em `out_custo_<etapa>/`.
Mantém a lógica do legado:
- custo_presente = soma(gt * custo) + soma(deficit * deficit_cost)
- custo_futuro = value(opt_config.alpha_vars)
- custo_total = presente + futuro
"""
function export_cost_csv(case, saida, opt_config, etapa::AbstractString, tempo_total::Real)
    etapa_s = String(etapa)
    reg = case.registry
    cfg = case.config
    caso = cfg.caso

    path_output = _ensure_outdir(case, "out_custo_$(etapa_s)")

    custo_presente = 0.0
    for periodo in 1:caso.n_periodos
        for ute in reg.lista_utes
            custo_presente += saida.gt_vars[(periodo, ute.nome, etapa_s)] * ute.custo
        end
    end

    if caso.Defs == 1
        for periodo in 1:caso.n_periodos
            for sbm in reg.lista_submercados
                custo_presente += saida.deficit_vars[(periodo, sbm.nome, etapa_s)] * sbm.deficit_cost
            end
        end
    end

    custo_futuro = (caso.Cortes == 1) ? value(opt_config.alpha_vars) : 0.0
    custo_total = custo_presente + custo_futuro

    filepath = joinpath(path_output, "custo_total_operacao.csv")
    oper = DataFrame(
        tempo = Float64(tempo_total),
        custo_pres = custo_presente,
        custo_fut = custo_futuro,
        custo_tot = custo_total,
    )
    CSV.write(filepath, oper)
    return filepath
end

# ------------------------------------------------------------------------------
# CMO (duais do balanço)
# ------------------------------------------------------------------------------

"""
    export_cmo_csv(case, saida, opt_config, etapa)

Calcula os duais de `constraint_balancDem_dict` no `opt_config` e salva em `out_cmo/cmos.csv`.
Mantém a lógica do legado: valores negativos viram 0 no gráfico (isso fica no gráfico),
mas no CSV gravamos o valor como está (igual ao legado gravava).
"""
function export_cmo_csv(case, saida, opt_config, etapa::AbstractString)
    etapa_s = String(etapa)
    reg = case.registry
    cfg = case.config
    caso = cfg.caso

    path_output = _ensure_outdir(case, "out_cmo")

    # guarda duals dentro do próprio saida
    for periodo in 1:caso.n_periodos
        for sbm in reg.lista_submercados
            saida.constraint_balancDem_dict[(periodo, sbm.nome, etapa_s)] =
                dual(opt_config.constraint_balancDem_dict[(periodo, sbm.nome, etapa_s)])
        end
    end

    periodos_list = Int[]
    submercado_list = Any[]
    cmos_list = Float64[]

    for sbm in reg.lista_submercados
        for periodo in 1:caso.n_periodos
            push!(periodos_list, periodo)
            push!(submercado_list, sbm.codigo)
            push!(cmos_list, saida.constraint_balancDem_dict[(periodo, sbm.nome, etapa_s)])
        end
    end

    filepath = joinpath(path_output, "cmos.csv")
    cmos_df = DataFrame(periodo = periodos_list, cmo = cmos_list, submercado = submercado_list)
    CSV.write(filepath, cmos_df)
    return filepath
end

# ------------------------------------------------------------------------------
# REDE (fluxos DC)
# ------------------------------------------------------------------------------

"""
    export_network_flows_csv(case, saida, etapa; round_digits=4)

Gera `fluxos.csv` em `out_rede_<etapa>/`, equivalente ao `output_rede` legado,
mas usando a camada Network do projeto (PTDF/DC flow).

- β = Network.build_ptdf(...)
- P = Network.build_P(...)
- G (numérico) é construído a partir de `saida` (não do opt_config)
- fluxo[t] = β*(G[t]-P[t])
- grava um registro por (periodo, linha)
"""
function export_network_flows_csv(case, saida, etapa::AbstractString; round_digits::Int = 4)
    etapa_s = String(etapa)
    cfg = case.config
    caso = cfg.caso

    if caso.Rede != 1
        return nothing
    end

    op = case.operation
    reg = case.registry

    path_output = _ensure_outdir(case, "out_rede_$(etapa_s)")

    β = Network.build_ptdf(op.Num_BAR, op.Num_LIN, op.lista_linhas, op.lista_barras)
    P = Network.build_P(op.lista_barras)

    # Constrói G numérico por período e barra (sem slack) a partir de `saida`
    function _G_from_saida(periodo::Int)
        # acumulador por barra (exceto 1)
        Gs = Dict{Int, Float64}()
        for b in op.lista_barras
            if b.periodo == periodo && b.codigo != 1
                Gs[b.codigo] = 0.0
            end
        end

        # térmicas
        if reg.existe_term > 0
            for ute in reg.lista_utes
                if ute.barra != 1
                    Gs[ute.barra] += saida.gt_vars[(periodo, ute.nome, etapa_s)]
                end
            end
        end

        # hídrica
        if reg.existe_hid > 0
            for uhe in reg.lista_uhes
                unidades = reg.mapaUHEunidades[uhe.nome]
                for un in unidades
                    if un.barra != 1
                        conj = reg.mapaUnidadeConjunto[un].codigo
                        Gs[un.barra] += saida.gh_vars[(periodo, uhe.nome, conj, un.codigo, etapa_s)]
                    end
                end
            end
        end

        # eólica
        if reg.existe_eol > 0
            for eol in reg.lista_eols
                if eol.barra != 1
                    Gs[eol.barra] += saida.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)]
                end
            end
        end

        # empacota em vetor seguindo a ordem das barras (periodo) e removendo barra 1
        vecG = Float64[]
        for b in op.lista_barras
            if b.periodo == periodo && b.codigo != 1
                push!(vecG, Gs[b.codigo])
            end
        end
        return vecG
    end

    fluxos = Float64[]
    barras_de = Int[]
    barras_para = Int[]
    periodos = Int[]

    for periodo in 1:caso.n_periodos
        Gv = _G_from_saida(periodo)
        Pv = Float64[p for p in P[periodo]]

        f = vec(β * (Gv - Pv))

        for linha in op.lista_linhas
            push!(periodos, periodo)
            push!(barras_de, linha.barra_de)
            push!(barras_para, linha.barra_para)
            push!(fluxos, round(f[linha.codigo], digits=round_digits))
        end
    end

    filepath = joinpath(path_output, "fluxos.csv")
    df = DataFrame(periodo = periodos, barra_de = barras_de, barra_para = barras_para, fluxo = fluxos)
    CSV.write(filepath, df)
    return filepath
end