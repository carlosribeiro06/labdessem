using JuMP

"""
    extract_commitment(case, opt_config_milp; etapa="MILP") -> NamedTuple

Extrai valores da solução (MILP) para serem usados na fixação do LP em "PL_int_fix".

Retorna um NamedTuple com campos (podem existir vazios dependendo das flags):
- uct :: Dict{Tuple{Int,String},Float64}         chave: (periodo, ute_nome)
- y   :: Dict{Tuple{Int,String},Float64}
- w   :: Dict{Tuple{Int,String},Float64}
- uch :: Dict{Tuple{Int,String,Int,Int},Float64} chave: (periodo, uhe_nome, conj_codigo, unidade_codigo)

Parâmetros:
- `case`: retorno de `LabDessem.IO.load_case(...)`
- `opt_config_milp`: OtimizacaoConfig do MILP construído por `build_milp`
- `etapa`: string usada nas chaves dos dicionários dentro do opt_config (default "MILP")

Pré-requisito:
- o MILP precisa estar otimizado, para `value(...)` funcionar.
"""
function extract_commitment(case, opt_config_milp; etapa::AbstractString = "MILP")
    etapa_s = String(etapa)

    registry = case.registry
    cfg = case.config

    uct = Dict{Tuple{Int, String}, Float64}()
    y   = Dict{Tuple{Int, String}, Float64}()
    w   = Dict{Tuple{Int, String}, Float64}()
    uch = Dict{Tuple{Int, String, Int, Int}, Float64}()

    # -------------------------
    # Térmicas: uct / y / w
    # -------------------------
    if cfg.aciona_uct == 1 && registry.existe_term > 0
        for periodo in 1:cfg.caso.n_periodos
            for ute in registry.lista_utes
                key = (periodo, ute.nome)

                # uct
                v_uct = opt_config_milp.uct_vars[(periodo, ute.nome, etapa_s)]
                uct[key] = value(v_uct)

                # y
                if haskey(opt_config_milp.y_vars, (periodo, ute.nome, etapa_s))
                    y[key] = value(opt_config_milp.y_vars[(periodo, ute.nome, etapa_s)])
                end

                # w
                if haskey(opt_config_milp.w_vars, (periodo, ute.nome, etapa_s))
                    w[key] = value(opt_config_milp.w_vars[(periodo, ute.nome, etapa_s)])
                end
            end
        end
    end

    # -------------------------
    # Hidros: uch
    # -------------------------
    if cfg.aciona_uch == 1 && registry.existe_hid > 0
        for periodo in 1:cfg.caso.n_periodos
            for uhe in registry.lista_uhes
                unidades_uhe = registry.mapaUHEunidades[uhe.nome]
                for unidade in unidades_uhe
                    conj_codigo = registry.mapaUnidadeConjunto[unidade].codigo
                    key = (periodo, uhe.nome, conj_codigo, unidade.codigo)

                    v_uch = opt_config_milp.uch_vars[(periodo, uhe.nome, conj_codigo, unidade.codigo, etapa_s)]
                    uch[key] = value(v_uch)
                end
            end
        end
    end

    return (uct = uct, y = y, w = w, uch = uch)
end