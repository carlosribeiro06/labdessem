using LinearAlgebra
using JuMP
import ..Data: Violacao_Rede

"""
    check_network_violations(opt_config, etapa, case_config, registry, operation;
                             round_digits::Int=4)

Checa violações de fluxo DC em todas as linhas e períodos (pós-solve).

- Usa β = build_ptdf(...)
- Usa P = build_P(...)
- Usa G_expr = build_G(...) e avalia com value(...) para obter G numérico
- Fluxo[t] = β * (G[t] - P[t])
- Violação se abs(round(fluxo[t][linha.codigo], digits=round_digits)) > linha.capacidade

Retorna:
- lista_violacoes::Vector{Violacao_Rede}
- has_violation::Bool
- fluxo::Dict{Int, Vector{Float64}}
"""
function check_network_violations(
    opt_config,
    etapa::AbstractString,
    case_config,
    registry,
    operation;
    round_digits::Int = 4,
)
    caso = case_config.caso

    if caso.Rede != 1
        return Violacao_Rede[], false, Dict{Int, Vector{Float64}}()
    end

    num_bar = operation.Num_BAR
    num_lin = operation.Num_LIN
    lista_linhas = operation.lista_linhas
    lista_barras = operation.lista_barras

    β = build_ptdf(num_bar, num_lin, lista_linhas, lista_barras)
    P = build_P(lista_barras)  # Dict{Int, Vector} (cargas)

    G_expr = build_G(opt_config, etapa, caso, registry, lista_barras)

    fluxo = Dict{Int, Vector{Float64}}()
    lista_violacoes = Violacao_Rede[]

    for periodo in 1:caso.n_periodos
        # avalia vetor G no período
        Gv = Float64[value(x) for x in G_expr[periodo]]
        Pv = Float64[p for p in P[periodo]]

        f = β * (Gv - Pv)
        fluxo[periodo] = vec(f)

        for linha in lista_linhas
            if abs(round(fluxo[periodo][linha.codigo], digits = round_digits)) > linha.capacidade
                viol = Violacao_Rede()
                viol.periodo = periodo
                viol.linha = linha.codigo
                viol.capacidade = linha.capacidade
                push!(lista_violacoes, viol)
            end
        end
    end

    has_violation = !isempty(lista_violacoes)
    return lista_violacoes, has_violation, fluxo
end