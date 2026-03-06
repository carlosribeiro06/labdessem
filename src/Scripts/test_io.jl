#include(joinpath(@__DIR__, "..", "LabDessem.jl"))
#using .LabDessem

# A pasta exemplo fica na raiz do projeto (fora de src),
# e este script está em src/Scripts -> precisa subir 2 níveis.
#case_dir = normpath(joinpath(@__DIR__, "..", "..", "exemplo", "caso_teste_fpha_caso_grande_FCF_FCIE_teste"))

#@assert isdir(case_dir) "Diretório do caso não existe: $case_dir"

#cfg = LabDessem.IO.read_case_config(case_dir)
#@assert cfg.caso !== nothing "cfg.caso veio nothing"

#reg = LabDessem.IO.load_registry(case_dir, cfg.caso)
#@assert length(reg.lista_submercados) >= 1 "Nenhum submercado carregado"

#op = LabDessem.IO.load_operation_data(case_dir, cfg.caso, reg)
#@assert cfg.caso.n_periodos > 0 "n_periodos não foi atualizado (ou é <= 0)"
#@assert op.Num_LIN == length(op.lista_linhas) "Num_LIN inconsistente com lista_linhas"
#@assert length(op.mapa_periodo_hora) >= 1 "mapa_periodo_hora vazio"

#if cfg.caso.Cortes == 1
#    @assert op.alpha !== nothing 
#end

#println("✅ TESTE IO OK")
#println("case_dir        = ", case_dir)
#println("n_periodos      = ", cfg.caso.n_periodos)
#println("submercados     = ", length(reg.lista_submercados))
#println("uhes            = ", length(reg.lista_uhes))
#println("utes            = ", length(reg.lista_utes))
#println("eols            = ", length(reg.lista_eols))
#println("linhas          = ", length(op.lista_linhas))
#println("barras          = ", length(op.lista_barras))
#println("fpha (registros)= ", length(op.lista_fpha))
#println("cortes_ativo    = ", cfg.caso.Cortes)



#case = LabDessem.IO.load_case(case_dir)

#using JuMP, HiGHS
#m = Model(HiGHS.Optimizer)
#opt = LabDessem.Data.OtimizacaoConfig()
# (precisa existir deficit_vars criado antes para não dar KeyError)
# Este teste é só para verificar que o arquivo carrega e a função existe:
#@show LabDessem
