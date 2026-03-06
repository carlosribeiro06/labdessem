using Logging

"""
    load_case(case_dir::AbstractString; out_dir::Union{Nothing,AbstractString}=nothing)

Carrega um caso completo a partir do diretório `case_dir`:

- Config (JSON): `read_case_config`
- Registry (CADASTRO): `load_registry`
- Operação (OPERACAO): `load_operation_data`

Retorna um `NamedTuple` contendo:
- `case_dir`, `out_dir`
- `config`   (NamedTuple retornado por `read_case_config`)
- `registry` (NamedTuple retornado por `load_registry`)
- `operation` (NamedTuple retornado por `load_operation_data`)

Observações:
- `caso.n_periodos` é atualizado em `load_operation_data.
- `load_operation_data` também preenche demanda e custo de déficit em `registry.lista_submercados`.
"""

function load_case(case_dir::AbstractString; out_dir::Union{Nothing,AbstractString}=nothing)
    # Normaliza paths (sem depender do diretório corrente)
    _case_dir = normpath(String(case_dir))
    _out_dir = isnothing(out_dir) ? _case_dir : normpath(String(out_dir))

    if !isdir(_case_dir)
        error("Diretório do caso não encontrado: $(_case_dir)")
    end

    @info "Carregando caso" case_dir=_case_dir out_dir=_out_dir

    # 1) Config do caso (JSON)
    config = read_case_config(_case_dir)

    # 2) Registry (CADASTRO)
    registry = load_registry(_case_dir, config.caso)

    # 3) Operação (OPERACAO)
    operation = load_operation_data(_case_dir, config.caso, registry)

    @info "Caso carregado" n_periodos=config.caso.n_periodos

    return (;
        case_dir = _case_dir,
        out_dir = _out_dir,
        config = config,
        registry = registry,
        operation = operation,
    )
end