using JSON
using Logging

import ..Data: CaseData

"""
    _parse_json_file(path::AbstractString) -> Any

Parseia um arquivo JSON de forma compatível com diferentes versões do JSON.jl.

1) tenta `JSON.parsefile(path)` (mais comum e compatível)
2) se falhar, faz fallback lendo o arquivo como String e chamando `JSON.parse`
"""
function _parse_json_file(path::AbstractString)
    try
        return JSON.parsefile(path)
    catch
        open(path, "r") do io
            return JSON.parse(read(io, String))
        end
    end
end

"""
    read_case_config(case_dir::AbstractString; filename::AbstractString="chavesEntrada.json")

Lê o arquivo de configuração do caso (JSON) e retorna um `NamedTuple` contendo:

- `caso::CaseData` (flags preenchidas)
- `trata_ton`, `aciona_uct`, `aciona_uch`, `aciona_fpha` (flags auxiliares)
- `dict` (dicionário bruto do JSON)
"""
function read_case_config(case_dir::AbstractString; filename::AbstractString = "chavesEntrada.json")
    config_path = joinpath(case_dir, filename)
    @info "Lendo arquivo de configuração" path = config_path

    dict = _parse_json_file(config_path)

    caso = CaseData()

    # Flags do caso
    caso.Rest_Canal_Term      = dict["Rest_Canal_Term"]
    caso.Rest_Canal_Hid       = dict["Rest_Canal_Hid"]
    caso.Rest_Bal_Hid         = dict["Rest_Bal_Hid"]
    caso.Rest_Hid             = dict["Rest_Hid"]
    caso.Rest_Limites_Fluxo   = dict["Rest_Limites_Fluxo"]
    caso.Rest_Ton_Toff_Term   = dict["Rest_Ton_Toff_Term"]
    caso.Rest_Ton_Toff_Hid    = dict["Rest_Ton_Toff_Hid"]
    caso.Rest_Inter           = dict["LIMITES_INTERCAMBIO"]
    caso.Rest_Inter_Tabela    = dict["LIMITES_INTERCAMBIO_ENVELOPE_MCCORMICK"]
    caso.Graficos             = dict["Graficos"]
    caso.Rede                 = dict["REDE"]
    caso.Defs                 = dict["DEFS"]
    caso.Cortes               = dict["CORTES_EXTERNOS"]

    # Flags auxiliares
    trata_ton   = dict["TRATA_TON"]
    aciona_uct  = dict["UCT"]
    aciona_uch  = dict["UCH"]
    aciona_fpha = dict["FPHA"]

    return (;
        caso = caso,
        trata_ton = trata_ton,
        aciona_uct = aciona_uct,
        aciona_uch = aciona_uch,
        aciona_fpha = aciona_fpha,
        dict = dict,
    )
end