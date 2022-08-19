using UnicodePlots, Term
import REPL

struct GUIData
    cn0s::Dict{Int, typeof(1.0Hz)}
    pvt::PVTSolution
end

const PRNMARKERS = (
    '\U2780',
    '\U2781',
    '\U2782',
    '\U2783',
    '\U2784',
    '\U2785',
    '\U2786',
    '\U2787',
    '\U2788',
    '\U2789',
    '\U246A',
    '\U246B',
    '\U246C',
    '\U246D',
    '\U246E',
    '\U246F',
    '\U2470',
    '\U2471',
    '\U2472',
    '\U2473',
    '\U3251',
    '\U3252',
    '\U3253',
    '\U3254',
    '\U3255',
    '\U3256',
    '\U3257',
    '\U3258',
    '\U3259',
    '\U325A',
    '\U325B',
    '\U325C',
    '\U325D',
    '\U325E',
    '\U325F',
)

_cursor_hide(io::IO) = print(io, "\x1b[?25l")
_cursor_show(io::IO) = print(io, "\x1b[?25h")
panel(plot; kw...) = Panel(string(plot, color=true); fit=true, kw...)

function gui(gui_data_channel)
    terminal = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)
#    io = IOContext(PipeBuffer(), :color=>true)
    Base.errormonitor(@async begin
        dots_counter = 0
        consume_channel(gui_data_channel) do gui_data
            rounded_cn0s = Dict(
                prn => round(10*log10(linear(cn0) / Hz), digits = 1)
                for (prn, cn0) in gui_data.cn0s
            )
            pvt = gui_data.pvt
            sat_doa_panel_title = "Satellite Direction-of-Arrival (DOA)"
            position_panel_title = "User position"
            not_enought_sats_text = "Not enough satellites to calculate position."
    #           show(io, barplot(rounded_cn0s, ylabel = "Satellites", xlabel = "Carrier-to-Noise-Density-Ratio (CN0) [dBHz]"))
    #           out = read(io, String)
            panels = panel(barplot(rounded_cn0s, ylabel = "Satellites", xlabel = "Carrier-to-Noise-Density-Ratio (CN0) [dBHz]"), fit = true, title = "Carrier-to-Noise-Density-Ratio (CN0)")
            if !isnothing(pvt.time)
                sat_enus = map(sat_pos -> get_sat_enu(pvt.position, sat_pos), pvt.sat_positions)
                azs = map(x -> x.θ, sat_enus)
                els = map(x -> x.ϕ, sat_enus)
                prn_markers = map(prn -> PRNMARKERS[prn], pvt.used_sats)
                panels *= panel(polarplot(azs, els * 180 / π, rlim = (0, 90), scatter = true, marker = prn_markers), fit = true, title = sat_doa_panel_title)
                lla = get_LLA(pvt)
                panels *= Panel("Latitude: $(lla.lat)\nLongitude: $(lla.lon)\nAltitude: $(lla.alt)\nCompact:$(lla.lat),$(lla.lon)\nGoogle: https://www.google.com/maps/search/$(lla.lat),$(lla.lon)", fit = true, title = position_panel_title)
            elseif length(rounded_cn0s) < 4
                panels *= Panel(not_enought_sats_text, title = sat_doa_panel_title)
                panels *= Panel(not_enought_sats_text, title = position_panel_title)
            else
                dots_counter = mod(dots_counter + 1, 4)
                decoding_text = "Decoding satellites$(repeat(".", dots_counter))"
                panels *= Panel(decoding_text, title = sat_doa_panel_title, width = length(not_enought_sats_text) + 5)
                panels *= Panel(decoding_text, title = position_panel_title, width = length(not_enought_sats_text) + 5)
            end
            out = string(panels)
            REPL.Terminals.clear(terminal)
            _cursor_hide(stdout)
            println(out)
            _cursor_show(stdout)
        end
    end)
    return
end