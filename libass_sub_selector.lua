local ffi = require "ffi"
ffi.cdef[[
typedef struct ass_renderer ASS_Renderer;
typedef struct render_priv ASS_RenderPriv;
typedef struct parser_priv ASS_ParserPriv;
typedef struct ass_library ASS_Library;
typedef struct ass_style {char *Name; char *FontName; double FontSize; uint32_t PrimaryColour; uint32_t SecondaryColour; uint32_t OutlineColour; uint32_t BackColour; int Bold; int Italic; int Underline; int StrikeOut; double ScaleX; double ScaleY; double Spacing; double Angle; int BorderStyle; double Outline; double Shadow; int Alignment; int MarginL; int MarginR; int MarginV; int Encoding; int treat_fontname_as_pattern; double Blur; int Justify;} ASS_Style;
typedef struct ass_event {long long Start; long long Duration; int ReadOrder; int Layer; int Style; char *Name; int MarginL; int MarginR; int MarginV; char *Effect; char *Text; ASS_RenderPriv *render_priv;} ASS_Event;
typedef enum ASS_YCbCrMatrix {YCBCR_DEFAULT = 0, YCBCR_UNKNOWN, YCBCR_NONE, YCBCR_BT601_TV, YCBCR_BT601_PC, YCBCR_BT709_TV, YCBCR_BT709_PC, YCBCR_SMPTE240M_TV, YCBCR_SMPTE240M_PC, YCBCR_FCC_TV, YCBCR_FCC_PC} ASS_YCbCrMatrix;
typedef struct ass_track {int n_styles; int max_styles; int n_events; int max_events; ASS_Style *styles; ASS_Event *events; char *style_format; char *event_format; enum {TRACK_TYPE_UNKNOWN = 0, TRACK_TYPE_ASS, TRACK_TYPE_SSA} track_type; int PlayResX; int PlayResY; double Timer; int WrapStyle; int ScaledBorderAndShadow; int Kerning; char *Language; ASS_YCbCrMatrix YCbCrMatrix; int default_style; char *name; ASS_Library *library; ASS_ParserPriv *parser_priv;} ASS_Track;
typedef struct ass_image {int w, h; int stride; unsigned char *bitmap; uint32_t color; int dst_x, dst_y; struct ass_image *next; enum {IMAGE_TYPE_CHARACTER, IMAGE_TYPE_OUTLINE, IMAGE_TYPE_SHADOW} type;} ASS_Image;
ASS_Library *ass_library_init(void);
void ass_library_done(ASS_Library *);
ASS_Renderer *ass_renderer_init(ASS_Library *);
ASS_Image *ass_render_frame(ASS_Renderer *, ASS_Track *, long long, int *);
void ass_renderer_done(ASS_Renderer *);
ASS_Track *ass_read_file(ASS_Library *, const char *, const char *);
void ass_free_track(ASS_Track *);
ASS_Track *ass_new_track(ASS_Library *);
void ass_free_track(ASS_Track *);
int ass_alloc_style(ASS_Track *);
int ass_alloc_event(ASS_Track *);
long long ass_step_sub(ASS_Track *, long long, int);
void ass_set_frame_size(ASS_Renderer *, int, int);
void ass_set_fonts(ASS_Renderer *, const char *, const char *, int, const char *, int);
void ass_set_fonts_dir(ASS_Library *, const char *);
void *malloc(size_t);
char *strcpy(char *, const char *);
size_t strlen(const char *s);
]]
local ass = ffi.load("C:/Path/libass-9.dll", true)

local utils = require "mp.utils"
local assdraw = require "mp.assdraw"

local tmpass = "C:\\Users\\User\\AppData\\Local\\Temp\\subselect\\subs.ass"

local cache = {pos = -1, last = 0, w = -1, h = -1, events = {}, bounds = {}, mouse = {pos_x = -1, pos_y = -1, last = 0, autohide = nil}}

local pos = nil
local skip = false

local function strdup(src)
    local dst = ffi.C.malloc(ffi.C.strlen(src) + 1)
    return ffi.C.strcpy(dst, src)
end

local function copy_tmpfile(reload)
    mp.set_osd_ass(0, 0, "")
    local track_list = mp.get_property_native("track-list")
    for i, v in ipairs(track_list) do
        if v.type == 'sub' and v.selected and (v.codec == "ass" or v.codec == "ssa") then
            local working_directory = mp.get_property_native("working-directory")
            local path = mp.get_property_native("path")
            local file = utils.join_path(working_directory, path)
            mp.command_native{"subprocess", {
                "python",
                "C:\\Users\\MainUserW\\AppData\\Roaming\\mpv\\scripts\\shared\\attachments.py",
                file
            }}
            if not v.external then
                local index = v["ff-index"]
                mp.command_native{"subprocess", {
                    "ffmpeg", "-loglevel", "8",
                    "-i", file,
                    "-map", "0:" .. index,
                    "-y", tmpass
                }}
                -- mp.command_native{"subprocess", {
                --     "mkvextract",
                --     "tracks", file,
                --     index .. ":" .. tmpass
                -- }}
            else
                tmpass = v["external-filename"]
            end
            skip = false
            return
        end
    end
    skip = true
end

local library, renderer, track, events, width, height
local function init_libass()
    if skip then
        events = nil
        return
    end
    library = ffi.gc(ass.ass_library_init(), ass.ass_library_done)
    renderer = ffi.gc(ass.ass_renderer_init(library), ass.ass_renderer_done)
    width = mp.get_property_native("width")
    if not width then
        return
    end
    height = mp.get_property_native("height")
    ass.ass_set_frame_size(renderer, width, height)
    ass.ass_set_fonts_dir(library, "C:/Users/MainUserW/AppData/Local/Temp/subselect/fonts");
    ass.ass_set_fonts(renderer, nil, "sans-serif", 1, nil, 1);
    track = ffi.gc(ass.ass_read_file(library, tmpass, nil), ass.ass_free_track)
    events = {}
    for i = 0, track.n_events-1 do
        table.insert(events, track.events[i])
    end
    return events
end

local function event_track(event, i)
    if cache.events[i] then
        return cache.events[i]
    end
    local ret = ffi.gc(ass.ass_new_track(library), ass.ass_free_track)
    ret.style_format = strdup(track.style_format)
    ret.event_format = strdup(track.event_format)
    ret.track_type = track.track_type
    ret.PlayResX = track.PlayResX
    ret.PlayResY = track.PlayResY
    ret.WrapStyle = track.WrapStyle
    ret.ScaledBorderAndShadow = track.ScaledBorderAndShadow
    ret.Kerning = track.Kerning
    if track.Language ~= nil then
        ret.Language = strdup(track.Language)
    end
    ret.YCbCrMatrix = track.YCbCrMatrix
    if track.name ~= nil then
        ret.name = strdup(track.name)
    end
    local style_id = ass.ass_alloc_style(ret)
    ret.default_style = style_id
    local orig = track.styles[event.Style]
    ffi.copy(ret.styles[style_id], track.styles[event.Style], ffi.sizeof("ASS_Style"))
    ret.styles[style_id].Name = strdup(orig.Name)
    ret.styles[style_id].FontName = strdup(orig.FontName)
    local event_id = ass.ass_alloc_event(ret)
    local render_priv = ret.events[event_id].render_priv
    ffi.copy(ret.events[event_id], event, ffi.sizeof("ASS_Event"))
    ret.events[event_id].Name = strdup(event.Name)
    ret.events[event_id].Layer = event.Layer
    ret.events[event_id].Effect = strdup(event.Effect)
    ret.events[event_id].Text = strdup(event.Text)
    ret.events[event_id].Style = style_id
    ret.events[event_id].render_priv = render_priv
    cache.events[i] = ret
    return ret
end

local function bounds(b_track, time, index)
    if cache.bounds[index] then
        return unpack(cache.bounds[index])
    end
    print("uncached bounds")
    local change = ffi.new("int[1]")
    local image = ass.ass_render_frame(renderer, b_track, time, change)
    local min_x = width
    local min_y = height
    local max_x = 0
    local max_y = 0
    while image ~= nil do
        if image.dst_x < min_x then
            min_x = image.dst_x
        end
        if image.dst_y < min_y then
            min_y = image.dst_y
        end
        if (image.dst_x + image.w) > max_x then
            max_x = image.dst_x + image.w
        end
        if (image.dst_y + image.h) > max_y then
            max_y = image.dst_y + image.h
        end
        image = image.next
    end
    cache.bounds[index] = {min_x, min_y, max_x, max_y}
    return min_x, min_y, max_x, max_y
end

local function events_at(time)
    local ret = {}
    local index = 1
    for i, v in ipairs(events) do
        if v.Start <= time and time < (v.Start + v.Duration) then
            table.insert(ret, {event = v, index = index})
            index = index + 1
        end
    end
    return ret
end

local function copy_subs(text)
  print(text)
  local res = utils.subprocess_detached({ args = {
    'powershell', '-NoProfile', '-Command', string.format([[& {
      Trap {
        Write-Error -ErrorRecord $_
        Exit 1
      }
      Add-Type -AssemblyName PresentationCore
      [System.Windows.Clipboard]::SetText(@"
%s
"@)
    }]], text)
  } })
end

function compare_subs(a,b)
    if a.event.Layer == b.event.Layer then
        local a_min_x, a_min_y, a_max_x, a_max_y = bounds(event_track(a.event, a.index), pos * 1000, a.index)
        local b_min_x, b_min_y, b_max_x, b_max_y = bounds(event_track(b.event, b.index), pos * 1000, b.index)
        return (a_max_x - a_min_x) * (a_max_y - a_min_y) < (b_max_x - b_min_x) * (b_max_y - b_min_y)
    end
    return a.event.Layer > b.event.Layer
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.ceil(num * mult + 0.5) / mult
end

function get_virt_scale_factor()
    local width = mp.get_property_native("width")
    local height = mp.get_property_native("height")
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then
        return 0, 0
    end
    return width / w, height / h
end

local function tick(copy)
    if events == nil then return end
    pos = mp.get_property_native("time-pos")
    if not pos then return end
    local w, h = mp.get_osd_size()
    if pos ~= cache.pos or w ~= cache.w or h ~= cache.h then
        cache.last = -1
        cache.pos = pos
        cache.w = w
        cache.h = h
        cache.bounds = {}
        cache.events = {}
        cache.mouse.autohide = mp.get_property_native("cursor-autohide")
    end
    local events = events_at(pos * 1000)
    table.sort(events, compare_subs)
    local ass = assdraw.ass_new()
    local scale_x, scale_y = get_virt_scale_factor()
    local bigscale = scale_y
    if scale_x > scale_y then
        bigscale = scale_x
    end
    local offset_x = (w - width / bigscale) * bigscale / 2
    local offset_y = (h - height / bigscale) * bigscale / 2
    local x, y = mp.get_mouse_pos()
    local pos_x = (x - (w - width / bigscale) / 2) * bigscale
    local pos_y = (y - (h - height / bigscale) / 2) * bigscale
    for i, v in ipairs(events) do
        local track_event = event_track(v.event, v.index)
        local min_x, min_y, max_x, max_y = bounds(track_event, pos * 1000, v.index)
        if pos_x + offset_x > min_x + offset_x and pos_x + offset_x < max_x + offset_x and pos_y + offset_y > min_y + offset_y and pos_y + offset_y < max_y + offset_y then
            if copy == true then
                copy_subs(ffi.string(v.event.Text):gsub("{\\([^}]*p1.*?\\p0)[^}]*}", ""):gsub("{\\([^}]*p1)[^}]*}.*", ""):gsub("{\\[^}]+}", ""):gsub("\\N", "\n"):gsub("\\n", "\n"):gsub("\\h", " "))
            end
            if x ~= cache.mouse.pos_x or y ~= cache.mouse.pos_y then
                cache.mouse.pos_x = x
                cache.mouse.pos_y = y
                cache.mouse.last = os.time()
            elseif type(cache.mouse.autohide) == "number" and (not mp.get_property_native("cursor-autohide-fs-only") or mp.get_property_native("fullscreen")) and os.time() * 1000 - cache.mouse.last * 1000 > round(cache.mouse.autohide, -3) then
                break
            end
            if cache.last == v.index then
                return
            end
            cache.last = v.index
            ass:new_event()
            ass:append("{\\3c&H0000ff&}")
            ass:append("{\\bord2}")
            ass:append("{\\1a&HFF&}")
            ass:pos(0, 0)
            ass:draw_start()
            ass:move_to(min_x + offset_x, min_y + offset_y)
            ass:line_to(max_x + offset_x, min_y + offset_y)
            ass:line_to(max_x + offset_x, max_y + offset_y)
            ass:line_to(min_x + offset_x, max_y + offset_y)
            ass:draw_stop()
            mp.set_osd_ass(width, height, ass.text)
            return
        end
    end
    if cache.last ~= 0 then
        mp.set_osd_ass(width, height, "")
    end
    cache.last = 0
end

local function file_loaded(reload)
    copy_tmpfile(reload)
    init_libass()
end

mp.register_event("file-loaded", file_loaded)
mp.register_event("tick", tick)

mp.add_key_binding("c", "copy-subs", function() return tick(true) end)
mp.add_key_binding("l", "reload-subs", function() return file_loaded(true) end)
