using Logging
include(joinpath(@__DIR__, "..", "LabDessem.jl"))
using .LabDessem

case_dir = normpath(joinpath(@__DIR__, "..", "..", "exemplo", "caso_teste_fpha_caso_grande_FCF_FCIE_teste"))
case = LabDessem.IO.load_case(case_dir)

res = LabDessem.Algorithms.run_dispatch(case; silent=true)

println("OK. Tempo total (solve) = ", res.total_solve_time)
println("Iterações LP = ", res.lp_iters, " | Iterações PL_int_fix = ", res.fix_iters)
println("Violações acumuladas = ", length(res.violations))