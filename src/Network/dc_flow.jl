using LinearAlgebra

"""
    build_B(num_bar, lista_linhas) -> Matrix{Float64}

Constrói a matriz B (susceptância nodal) e retorna B reduzida (removendo barra 1).

Assumptions:
- `linha.barra_de` e `linha.barra_para` são índices de barra (1..num_bar).
"""
function build_B(num_bar::Integer, lista_linhas)
    B = zeros(Float64, num_bar, num_bar)

    for linha in lista_linhas
        B[linha.barra_de, linha.barra_para] = -(1 / linha.reatancia)
        B[linha.barra_para, linha.barra_de] = -(1 / linha.reatancia)
        B[linha.barra_de, linha.barra_de]  += (1 / linha.reatancia)
        B[linha.barra_para, linha.barra_para] += (1 / linha.reatancia)
    end

    # remove barra slack (barra 1)
    return B[2:num_bar, 2:num_bar]
end

"""
    build_B_diag(lista_linhas) -> Matrix{Float64}

Constrói a matriz diagonal B_diag com 1/x para cada linha.

Assumption:
- `linha.codigo` é usado depois como índice de linha (1..Num_LIN) no fluxo.
"""
function build_B_diag(lista_linhas)
    diagonal = Float64[]
    for linha in lista_linhas
        push!(diagonal, 1 / linha.reatancia)
    end
    return diagm(0 => diagonal)
end

"""
    build_A(num_lin, num_bar, lista_linhas, lista_barras) -> Matrix{Float64}

Constrói a matriz de incidência A (linhas x barras), reduzida removendo barra 1:

- Preenche apenas para `barra.periodo == 1`
- Usa índices `A[linha.codigo, barra.codigo]`

Assumptions:
- `linha.codigo` ∈ 1..num_lin
- `barra.codigo` ∈ 1..num_bar
"""
function build_A(num_lin::Integer, num_bar::Integer, lista_linhas, lista_barras)
    A = zeros(Float64, num_lin, num_bar)

    for linha in lista_linhas
        for barra in lista_barras
            if barra.periodo == 1
                if barra.codigo == linha.barra_de
                    A[linha.codigo, barra.codigo] = 1
                end
                if barra.codigo == linha.barra_para
                    A[linha.codigo, barra.codigo] = -1
                end
            end
        end
    end

    # remove barra slack (barra 1)
    return A[:, 2:num_bar]
end

"""
    build_P(lista_barras) -> Dict{Int, Vector}

Monta o vetor de cargas por período (sem barra 1).
Retorna `P[periodo] = Vector` com cargas das barras (exceto barra 1) no período.
"""
function build_P(lista_barras)
    Ps = Dict{Int, Vector}()

    # inicializa chaves por período (para barras != 1), como no original
    for barra in lista_barras
        if barra.codigo != 1
            Ps[barra.periodo] = []
        end
    end

    for barra in lista_barras
        if barra.codigo != 1
            push!(Ps[barra.periodo], barra.carga)
        end
    end

    return Ps
end

"""
    build_G(opt_config, etapa, caso, registry, lista_barras) -> Dict{Int, Vector}

Monta o vetor de geração por período (sem barra 1).

- Soma térmica (gt_vars) por barra
- Soma hídrica (gh_vars) por barra
- Soma eólica (geol_vars) por barra

Retorna `G[periodo] = Vector` com expressões JuMP (ou valores) por barra (exceto barra 1).

Entradas esperadas em `registry`:
- existe_term, existe_hid, existe_eol
- lista_utes, lista_uhes, lista_eols
- mapaUHEunidades, mapaUnidadeConjunto
"""
function build_G(opt_config, etapa::AbstractString, caso, registry, lista_barras)
    etapa_s = String(etapa)

    # Dict para acumular por (periodo, barra)
    Gs = Dict{Tuple{Int, Int}, Any}()

    # inicializa com zero para barras != 1
    for barra in lista_barras
        if barra.codigo != 1
            Gs[(barra.periodo, barra.codigo)] = 0
        end
    end

    for periodo in 1:caso.n_periodos
        # térmicas
        if registry.existe_term > 0
            for ute in registry.lista_utes
                if ute.barra != 1
                    Gs[(periodo, ute.barra)] += opt_config.gt_vars[(periodo, ute.nome, etapa_s)]
                end
            end
        end

        # hídrica
        if registry.existe_hid > 0
            for uhe in registry.lista_uhes
                unidades_uhe = registry.mapaUHEunidades[uhe.nome]
                for unidade in unidades_uhe
                    if unidade.barra != 1
                        conj_codigo = registry.mapaUnidadeConjunto[unidade].codigo
                        Gs[(periodo, unidade.barra)] += opt_config.gh_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)]
                    end
                end
            end
        end

        # eólica
        if registry.existe_eol > 0
            for eol in registry.lista_eols
                if eol.barra != 1
                    Gs[(periodo, eol.barra)] += opt_config.geol_vars[(periodo, eol.posto, eol.nome, etapa_s)]
                end
            end
        end
    end

    # empacota em vetores por período (sem barra 1)
    output = Dict{Int, Vector}()
    for barra in lista_barras
        output[barra.periodo] = []
    end

    for barra in lista_barras
        if barra.codigo != 1
            push!(output[barra.periodo], Gs[(barra.periodo, barra.codigo)])
        end
    end

    return output
end

"""
    build_ptdf(num_bar, num_lin, lista_linhas, lista_barras) -> Matrix{Float64}

Computa β = B_diag * A * inv(B) (PTDF-like) mantendo o original.
"""
function build_ptdf(num_bar::Integer, num_lin::Integer, lista_linhas, lista_barras)
    B = build_B(num_bar, lista_linhas)
    B_diag = build_B_diag(lista_linhas)
    A = build_A(num_lin, num_bar, lista_linhas, lista_barras)
    return B_diag * A * inv(B)
end