using JuMP
using LinearAlgebra

import ..Data: Violacao_Rede

"""
    add_flow_cuts!(model, opt_config, etapa, case_config, registry, operation, violacoes;
                   name_prefix="lim_fluxo")

Adiciona restrições de limite de fluxo para as violações fornecidas.

Lógica mantida do original:
- Se caso.Rede == 1:
    β = B_diag * A * inv(B)
    fluxo[t] = β * (G[t] - P[t])
    Para cada violação em `violacoes`:
        fluxo[violacao.periodo][violacao.linha] >= -violacao.capacidade
        fluxo[violacao.periodo][violacao.linha] <=  violacao.capacidade

Entradas esperadas:
- `case_config`: NamedTuple com `caso`
- `registry`: NamedTuple com dados necessários para build_G
- `operation`: NamedTuple com Num_BAR, Num_LIN, lista_linhas, lista_barras
- `violacoes`: Vector{Violacao_Rede} (ou vetor compatível com campos periodo/linha/capacidade)

Retorna: `nothing`
"""
function add_flow_cuts!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
    registry,
    operation,
    violacoes;
    name_prefix::AbstractString = "lim_fluxo",
)
    caso = case_config.caso

    if caso.Rede != 1
        return nothing
    end

    num_bar = operation.Num_BAR
    num_lin = operation.Num_LIN
    lista_linhas = operation.lista_linhas
    lista_barras = operation.lista_barras

    # Reconstrói β, P e G
    β = build_ptdf(num_bar, num_lin, lista_linhas, lista_barras)
    P = build_P(lista_barras)
    G = build_G(opt_config, etapa, caso, registry, lista_barras)

    # Fluxo por período
    fluxo = Dict{Int, Any}()
    for periodo in 1:caso.n_periodos
        fluxo[periodo] = β * (G[periodo] - P[periodo])
    end

    # Adiciona cortes para cada violação
    for violacao in violacoes
        t = violacao.periodo
        l = violacao.linha
        cap = violacao.capacidade

        c1 = @constraint(model, fluxo[t][l] >= -cap)
        c2 = @constraint(model, fluxo[t][l] <=  cap)

        # Nomeia
        JuMP.set_name(c1, name_prefix)
        JuMP.set_name(c2, name_prefix)
    end

    return nothing
end