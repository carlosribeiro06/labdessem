using JuMP
using DataFrames

"""
    add_alpha_cut_constraints!(model, opt_config, etapa, case_config, operation)

Adiciona as restrições de alpha (cortes).

Lógica mantida do original:
- Se caso.Cortes == 1:
  Para cada corte em operation.alpha.cortes:
    df = filter(row -> row.corte == corte, operation.dat_fcf)
    temp = sum(vf[T, usi.Usina, etapa] * usi.coefs + usi.Termo_indep/2)
    alpha >= temp
  E alpha >= 0

Entradas esperadas:
- case_config: NamedTuple com `caso`
- operation: NamedTuple com `dat_fcf` e `alpha` (alpha pode ser `nothing` quando Cortes==0)
"""
function add_alpha_cut_constraints!(
    model::JuMP.Model,
    opt_config,
    etapa::AbstractString,
    case_config,
    operation,
)
    etapa_s = String(etapa)
    caso = case_config.caso

    if caso.Cortes == 1
        alpha_obj = operation.alpha
        dat_fcf = operation.dat_fcf

        if alpha_obj === nothing
            error("caso.Cortes == 1, mas operation.alpha == nothing. Verifique load_operation_data/load_case.")
        end

        for corte in alpha_obj.cortes
            df = filter(row -> row.corte == corte, dat_fcf)

            temp = 0
            for usi in eachrow(df)
                temp += opt_config.vf_vars[(caso.n_periodos, usi.Usina, etapa_s)] * usi.coefs + usi.Termo_indep / 2
            end

            @constraint(model, opt_config.alpha_vars >= temp)
        end

        @constraint(model, opt_config.alpha_vars >= 0)
    end

    return nothing
end