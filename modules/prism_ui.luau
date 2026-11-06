-- ============================================================================
-- PRISM | UI LIBRARY
-- ============================================================================
-- Standalone script hub UI with a crystal intro.
--
-- DESIGN
-- Neutral surfaces with one accent. The spectrum colours belong to the
-- crystal logo and intro only; everything else is greyscale, with the
-- accent (a violet -> pink gradient) marking state: toggle on, slider
-- fill, selected tab. Gotham SSm at real weights, Lucide icons, faint
-- 1px outlines, small radii, a soft 9-slice drop shadow, and a light
-- shine that sweeps across active controls.
--
-- FEATURES
-- Window sidebar with categories, search (Ctrl+K), resize grip,
-- minimise-to-pill, opacity + background blur, UI scale,
-- accent underglow, drifting aurora, profile tier badge
-- Sections collapsible cards with a cursor spotlight, tabboxes
-- Elements toggle (switch / checkbox, inline colour, right-click
-- keybind), slider, dropdown (multi, search), player
-- dropdown, colour picker, textbox, keybind, button
-- (primary, confirm), button row, segmented, progress,
-- stat, label, paragraph, divider; any element can be locked
-- Overlays watermark with live readouts, keybind list, typed
-- notifications in any corner, dialogs, tooltips
-- System configs (save / load / delete / export / import /
-- autoload), theme presets + live accent, UI sounds,
-- reduce motion, a ready-made Settings tab, unload hooks
--
-- INTRO SEQUENCE (CreateWindow{ Intro = true }, the default)
-- 1. Screen dims + game blurs.
-- 2. Crystal dust drifts in; the gem's eight facets fly in from all sides
-- and lock together, then the stone flashes and settles.
-- 3. Title letters drop in, a loading bar fills through status steps.
-- 4. Window fades in, the gem winds up, arcs across the screen trailing
-- sparks and drops into the socket in the window's top-left corner.
-- The brand text slides out from behind it.
--
-- The intro runs in its own thread. CreateWindow returns immediately so you
-- can build tabs while it plays; they're hidden until the window fades in.
--
-- OBJECT CHAIN
-- Prism:CreateWindow{} -> Window
-- Window:Tab{} -> Tab
-- Tab:Section{} -> Section
-- Section:Toggle{} etc. -> Element (:Set(), :Get(), .Value)
--
-- Every element takes Name and an optional Description (a second line of
-- smaller text under the name). Tabs and sections take an optional Icon:
-- a name from Prism.Icons (e.g. "sword") or an "rbxassetid://" string.
--
-- See Example.lua for every element.
--
-- CREDITS
-- Lucide icons (ISC) via the asset ids published in Fluent (MIT,
-- dawid-scripts). Window and popup shadow images also from Fluent.
-- ============================================================================

local cloneref = cloneref or function(o) return o end
local function svc(name) return cloneref(game:GetService(name)) end

local Players = svc("Players")
local TweenService = svc("TweenService")
local UserInputService = svc("UserInputService")
local RunService = svc("RunService")
local Lighting = svc("Lighting")
local CoreGui = svc("CoreGui")
local HttpService = svc("HttpService")
local SoundService = svc("SoundService")

local LocalPlayer = Players.LocalPlayer

local Prism = {
 Version = "3.0.0",
 Flags = {},

 -- Global preferences (all exposed in Window:SettingsTab()).
 ReduceMotion = false, -- turns off shine, ripples, spotlight, aurora drift
 Tooltips = true,
 Sounds = false,
 SoundVolume = 0.5,
}

-- ============================================================================
-- THEME
-- ============================================================================
local Theme = {
 Background = Color3.fromRGB(12, 12, 14),
 Surface = Color3.fromRGB(17, 17, 20),
 Element = Color3.fromRGB(23, 23, 27),
 ElementHover = Color3.fromRGB(29, 29, 34),
 ElementPress = Color3.fromRGB(35, 35, 41),
 Input = Color3.fromRGB(14, 14, 17),
 Stroke = Color3.fromRGB(42, 42, 48),

 -- Faint white hairline used for every outline.
 Outline = Color3.new(1, 1, 1),
 OutlineTransparency = 0.95,

 Text = Color3.fromRGB(242, 242, 245),
 SubText = Color3.fromRGB(161, 161, 170),
 Muted = Color3.fromRGB(113, 113, 122),

 -- Taken from the logo, between its pink and violet facets. Change it at
 -- runtime with Prism:SetAccent(color).
 Accent = Color3.fromRGB(150, 122, 255),

 Success = Color3.fromRGB(74, 222, 128),
 Warning = Color3.fromRGB(251, 191, 36),
 Error = Color3.fromRGB(248, 113, 113),

 -- Logo and intro only.
 Spectrum = {
 Color3.fromRGB(255, 110, 199),
 Color3.fromRGB(170, 125, 255),
 Color3.fromRGB(96, 165, 255),
 Color3.fromRGB(94, 234, 212),
 },
}
Prism.Theme = Theme

local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local Fonts = {
 Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
 Medium = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
 SemiBold = Font.new(FONT_FAMILY, Enum.FontWeight.SemiBold),
 Bold = Font.new(FONT_FAMILY, Enum.FontWeight.Bold),
}
Prism.Fonts = Fonts

local function spectrumSequence()
 local s = Theme.Spectrum
 return ColorSequence.new({
 ColorSequenceKeypoint.new(0, s[1]),
 ColorSequenceKeypoint.new(0.35, s[2]),
 ColorSequenceKeypoint.new(0.7, s[3]),
 ColorSequenceKeypoint.new(1, s[4]),
 })
end

local function randomSpectrum()
 return Theme.Spectrum[math.random(1, #Theme.Spectrum)]
end

-- Second stop of the accent gradient: the accent nudged toward pink.
local function accentAlt(color)
 local h, s, v = color:ToHSV()
 return Color3.fromHSV((h + 0.08) % 1, s, math.min(1, v * 1.05))
end

local function accentSequence()
 return ColorSequence.new(Theme.Accent, accentAlt(Theme.Accent))
end

-- ============================================================================
-- ICONS
-- ============================================================================
-- Lucide subset. Add more from the full map in
-- References/Fluent/src/Icons.lua (drop the "lucide-" prefix).
-- ============================================================================
local Icons = {
 ["accessibility"] = "rbxassetid://10709751939",
 ["activity"] = "rbxassetid://10709752035",
 ["air-vent"] = "rbxassetid://10709752131",
 ["airplay"] = "rbxassetid://10709752254",
 ["alarm-check"] = "rbxassetid://10709752405",
 ["alarm-clock"] = "rbxassetid://10709752630",
 ["alarm-clock-off"] = "rbxassetid://10709752508",
 ["alarm-minus"] = "rbxassetid://10709752732",
 ["alarm-plus"] = "rbxassetid://10709752825",
 ["album"] = "rbxassetid://10709752906",
 ["alert-circle"] = "rbxassetid://10709752996",
 ["alert-octagon"] = "rbxassetid://10709753064",
 ["alert-triangle"] = "rbxassetid://10709753149",
 ["align-center"] = "rbxassetid://10709753570",
 ["align-center-horizontal"] = "rbxassetid://10709753272",
 ["align-center-vertical"] = "rbxassetid://10709753421",
 ["align-end-horizontal"] = "rbxassetid://10709753692",
 ["align-end-vertical"] = "rbxassetid://10709753808",
 ["align-horizontal-distribute-center"] = "rbxassetid://10747779791",
 ["align-horizontal-distribute-end"] = "rbxassetid://10747784534",
 ["align-horizontal-distribute-start"] = "rbxassetid://10709754118",
 ["align-horizontal-justify-center"] = "rbxassetid://10709754204",
 ["align-horizontal-justify-end"] = "rbxassetid://10709754317",
 ["align-horizontal-justify-start"] = "rbxassetid://10709754436",
 ["align-horizontal-space-around"] = "rbxassetid://10709754590",
 ["align-horizontal-space-between"] = "rbxassetid://10709754749",
 ["align-justify"] = "rbxassetid://10709759610",
 ["align-left"] = "rbxassetid://10709759764",
 ["align-right"] = "rbxassetid://10709759895",
 ["align-start-horizontal"] = "rbxassetid://10709760051",
 ["align-start-vertical"] = "rbxassetid://10709760244",
 ["align-vertical-distribute-center"] = "rbxassetid://10709760351",
 ["align-vertical-distribute-end"] = "rbxassetid://10709760434",
 ["align-vertical-distribute-start"] = "rbxassetid://10709760612",
 ["align-vertical-justify-center"] = "rbxassetid://10709760814",
 ["align-vertical-justify-end"] = "rbxassetid://10709761003",
 ["align-vertical-justify-start"] = "rbxassetid://10709761176",
 ["align-vertical-space-around"] = "rbxassetid://10709761324",
 ["align-vertical-space-between"] = "rbxassetid://10709761434",
 ["anchor"] = "rbxassetid://10709761530",
 ["angry"] = "rbxassetid://10709761629",
 ["annoyed"] = "rbxassetid://10709761722",
 ["aperture"] = "rbxassetid://10709761813",
 ["apple"] = "rbxassetid://10709761889",
 ["archive"] = "rbxassetid://10709762233",
 ["archive-restore"] = "rbxassetid://10709762058",
 ["armchair"] = "rbxassetid://10709762327",
 ["arrow-big-down"] = "rbxassetid://10747796644",
 ["arrow-big-left"] = "rbxassetid://10709762574",
 ["arrow-big-right"] = "rbxassetid://10709762727",
 ["arrow-big-up"] = "rbxassetid://10709762879",
 ["arrow-down"] = "rbxassetid://10709767827",
 ["arrow-down-circle"] = "rbxassetid://10709763034",
 ["arrow-down-left"] = "rbxassetid://10709767656",
 ["arrow-down-right"] = "rbxassetid://10709767750",
 ["arrow-left"] = "rbxassetid://10709768114",
 ["arrow-left-circle"] = "rbxassetid://10709767936",
 ["arrow-left-right"] = "rbxassetid://10709768019",
 ["arrow-right"] = "rbxassetid://10709768347",
 ["arrow-right-circle"] = "rbxassetid://10709768226",
 ["arrow-up"] = "rbxassetid://10709768939",
 ["arrow-up-circle"] = "rbxassetid://10709768432",
 ["arrow-up-down"] = "rbxassetid://10709768538",
 ["arrow-up-left"] = "rbxassetid://10709768661",
 ["arrow-up-right"] = "rbxassetid://10709768787",
 ["asterisk"] = "rbxassetid://10709769095",
 ["at-sign"] = "rbxassetid://10709769286",
 ["award"] = "rbxassetid://10709769406",
 ["axe"] = "rbxassetid://10709769508",
 ["axis-3d"] = "rbxassetid://10709769598",
 ["baby"] = "rbxassetid://10709769732",
 ["backpack"] = "rbxassetid://10709769841",
 ["baggage-claim"] = "rbxassetid://10709769935",
 ["banana"] = "rbxassetid://10709770005",
 ["banknote"] = "rbxassetid://10709770178",
 ["bar-chart"] = "rbxassetid://10709773755",
 ["bar-chart-2"] = "rbxassetid://10709770317",
 ["bar-chart-3"] = "rbxassetid://10709770431",
 ["bar-chart-4"] = "rbxassetid://10709770560",
 ["bar-chart-horizontal"] = "rbxassetid://10709773669",
 ["barcode"] = "rbxassetid://10747360675",
 ["baseline"] = "rbxassetid://10709773863",
 ["bath"] = "rbxassetid://10709773963",
 ["battery"] = "rbxassetid://10709774640",
 ["battery-charging"] = "rbxassetid://10709774068",
 ["battery-full"] = "rbxassetid://10709774206",
 ["battery-low"] = "rbxassetid://10709774370",
 ["battery-medium"] = "rbxassetid://10709774513",
 ["beaker"] = "rbxassetid://10709774756",
 ["bed"] = "rbxassetid://10709775036",
 ["bed-double"] = "rbxassetid://10709774864",
 ["bed-single"] = "rbxassetid://10709774968",
 ["beer"] = "rbxassetid://10709775167",
 ["bell"] = "rbxassetid://10709775704",
 ["bell-minus"] = "rbxassetid://10709775241",
 ["bell-off"] = "rbxassetid://10709775320",
 ["bell-plus"] = "rbxassetid://10709775448",
 ["bell-ring"] = "rbxassetid://10709775560",
 ["bike"] = "rbxassetid://10709775894",
 ["binary"] = "rbxassetid://10709776050",
 ["bitcoin"] = "rbxassetid://10709776126",
 ["bluetooth"] = "rbxassetid://10709776655",
 ["bluetooth-connected"] = "rbxassetid://10709776240",
 ["bluetooth-off"] = "rbxassetid://10709776344",
 ["bluetooth-searching"] = "rbxassetid://10709776501",
 ["bold"] = "rbxassetid://10747813908",
 ["bomb"] = "rbxassetid://10709781460",
 ["bone"] = "rbxassetid://10709781605",
 ["book"] = "rbxassetid://10709781824",
 ["book-open"] = "rbxassetid://10709781717",
 ["bookmark"] = "rbxassetid://10709782154",
 ["bookmark-minus"] = "rbxassetid://10709781919",
 ["bookmark-plus"] = "rbxassetid://10709782044",
 ["bot"] = "rbxassetid://10709782230",
 ["box"] = "rbxassetid://10709782497",
 ["box-select"] = "rbxassetid://10709782342",
 ["boxes"] = "rbxassetid://10709782582",
 ["briefcase"] = "rbxassetid://10709782662",
 ["brush"] = "rbxassetid://10709782758",
 ["bug"] = "rbxassetid://10709782845",
 ["building"] = "rbxassetid://10709783051",
 ["building-2"] = "rbxassetid://10709782939",
 ["bus"] = "rbxassetid://10709783137",
 ["cake"] = "rbxassetid://10709783217",
 ["calculator"] = "rbxassetid://10709783311",
 ["calendar"] = "rbxassetid://10709789505",
 ["calendar-check"] = "rbxassetid://10709783474",
 ["calendar-check-2"] = "rbxassetid://10709783392",
 ["calendar-clock"] = "rbxassetid://10709783577",
 ["calendar-days"] = "rbxassetid://10709783673",
 ["calendar-heart"] = "rbxassetid://10709783835",
 ["calendar-minus"] = "rbxassetid://10709783959",
 ["calendar-off"] = "rbxassetid://10709788784",
 ["calendar-plus"] = "rbxassetid://10709788937",
 ["calendar-range"] = "rbxassetid://10709789053",
 ["calendar-search"] = "rbxassetid://10709789200",
 ["calendar-x"] = "rbxassetid://10709789407",
 ["calendar-x-2"] = "rbxassetid://10709789329",
 ["camera"] = "rbxassetid://10709789686",
 ["camera-off"] = "rbxassetid://10747822677",
 ["car"] = "rbxassetid://10709789810",
 ["carrot"] = "rbxassetid://10709789960",
 ["cast"] = "rbxassetid://10709790097",
 ["charge"] = "rbxassetid://10709790202",
 ["check"] = "rbxassetid://10709790644",
 ["check-circle"] = "rbxassetid://10709790387",
 ["check-circle-2"] = "rbxassetid://10709790298",
 ["check-square"] = "rbxassetid://10709790537",
 ["chef-hat"] = "rbxassetid://10709790757",
 ["cherry"] = "rbxassetid://10709790875",
 ["chevron-down"] = "rbxassetid://10709790948",
 ["chevron-first"] = "rbxassetid://10709791015",
 ["chevron-last"] = "rbxassetid://10709791130",
 ["chevron-left"] = "rbxassetid://10709791281",
 ["chevron-right"] = "rbxassetid://10709791437",
 ["chevron-up"] = "rbxassetid://10709791523",
 ["chevrons-down"] = "rbxassetid://10709796864",
 ["chevrons-down-up"] = "rbxassetid://10709791632",
 ["chevrons-left"] = "rbxassetid://10709797151",
 ["chevrons-left-right"] = "rbxassetid://10709797006",
 ["chevrons-right"] = "rbxassetid://10709797382",
 ["chevrons-right-left"] = "rbxassetid://10709797274",
 ["chevrons-up"] = "rbxassetid://10709797622",
 ["chevrons-up-down"] = "rbxassetid://10709797508",
 ["chrome"] = "rbxassetid://10709797725",
 ["circle"] = "rbxassetid://10709798174",
 ["circle-dot"] = "rbxassetid://10709797837",
 ["circle-ellipsis"] = "rbxassetid://10709797985",
 ["circle-slashed"] = "rbxassetid://10709798100",
 ["citrus"] = "rbxassetid://10709798276",
 ["clapperboard"] = "rbxassetid://10709798350",
 ["clipboard"] = "rbxassetid://10709799288",
 ["clipboard-check"] = "rbxassetid://10709798443",
 ["clipboard-copy"] = "rbxassetid://10709798574",
 ["clipboard-edit"] = "rbxassetid://10709798682",
 ["clipboard-list"] = "rbxassetid://10709798792",
 ["clipboard-signature"] = "rbxassetid://10709798890",
 ["clipboard-type"] = "rbxassetid://10709798999",
 ["clipboard-x"] = "rbxassetid://10709799124",
 ["clock"] = "rbxassetid://10709805144",
 ["clock-1"] = "rbxassetid://10709799535",
 ["clock-10"] = "rbxassetid://10709799718",
 ["clock-11"] = "rbxassetid://10709799818",
 ["clock-12"] = "rbxassetid://10709799962",
 ["clock-2"] = "rbxassetid://10709803876",
 ["clock-3"] = "rbxassetid://10709803989",
 ["clock-4"] = "rbxassetid://10709804164",
 ["clock-5"] = "rbxassetid://10709804291",
 ["clock-6"] = "rbxassetid://10709804435",
 ["clock-7"] = "rbxassetid://10709804599",
 ["clock-8"] = "rbxassetid://10709804784",
 ["clock-9"] = "rbxassetid://10709804996",
 ["cloud"] = "rbxassetid://10709806740",
 ["cloud-cog"] = "rbxassetid://10709805262",
 ["cloud-drizzle"] = "rbxassetid://10709805371",
 ["cloud-fog"] = "rbxassetid://10709805477",
 ["cloud-hail"] = "rbxassetid://10709805596",
 ["cloud-lightning"] = "rbxassetid://10709805727",
 ["cloud-moon"] = "rbxassetid://10709805942",
 ["cloud-moon-rain"] = "rbxassetid://10709805838",
 ["cloud-off"] = "rbxassetid://10709806060",
 ["cloud-rain"] = "rbxassetid://10709806277",
 ["cloud-rain-wind"] = "rbxassetid://10709806166",
 ["cloud-snow"] = "rbxassetid://10709806374",
 ["cloud-sun"] = "rbxassetid://10709806631",
 ["cloud-sun-rain"] = "rbxassetid://10709806475",
 ["cloudy"] = "rbxassetid://10709806859",
 ["clover"] = "rbxassetid://10709806995",
 ["code"] = "rbxassetid://10709810463",
 ["code-2"] = "rbxassetid://10709807111",
 ["codepen"] = "rbxassetid://10709810534",
 ["codesandbox"] = "rbxassetid://10709810676",
 ["coffee"] = "rbxassetid://10709810814",
 ["cog"] = "rbxassetid://10709810948",
 ["coins"] = "rbxassetid://10709811110",
 ["columns"] = "rbxassetid://10709811261",
 ["command"] = "rbxassetid://10709811365",
 ["compass"] = "rbxassetid://10709811445",
 ["component"] = "rbxassetid://10709811595",
 ["concierge-bell"] = "rbxassetid://10709811706",
 ["connection"] = "rbxassetid://10747361219",
 ["contact"] = "rbxassetid://10709811834",
 ["contrast"] = "rbxassetid://10709811939",
 ["cookie"] = "rbxassetid://10709812067",
 ["copy"] = "rbxassetid://10709812159",
 ["copyleft"] = "rbxassetid://10709812251",
 ["copyright"] = "rbxassetid://10709812311",
 ["corner-down-left"] = "rbxassetid://10709812396",
 ["corner-down-right"] = "rbxassetid://10709812485",
 ["corner-left-down"] = "rbxassetid://10709812632",
 ["corner-left-up"] = "rbxassetid://10709812784",
 ["corner-right-down"] = "rbxassetid://10709812939",
 ["corner-right-up"] = "rbxassetid://10709813094",
 ["corner-up-left"] = "rbxassetid://10709813185",
 ["corner-up-right"] = "rbxassetid://10709813281",
 ["cpu"] = "rbxassetid://10709813383",
 ["croissant"] = "rbxassetid://10709818125",
 ["crop"] = "rbxassetid://10709818245",
 ["cross"] = "rbxassetid://10709818399",
 ["crosshair"] = "rbxassetid://10709818534",
 ["crown"] = "rbxassetid://10709818626",
 ["cup-soda"] = "rbxassetid://10709818763",
 ["curly-braces"] = "rbxassetid://10709818847",
 ["currency"] = "rbxassetid://10709818931",
 ["database"] = "rbxassetid://10709818996",
 ["delete"] = "rbxassetid://10709819059",
 ["diamond"] = "rbxassetid://10709819149",
 ["dice-1"] = "rbxassetid://10709819266",
 ["dice-2"] = "rbxassetid://10709819361",
 ["dice-3"] = "rbxassetid://10709819508",
 ["dice-4"] = "rbxassetid://10709819670",
 ["dice-5"] = "rbxassetid://10709819801",
 ["dice-6"] = "rbxassetid://10709819896",
 ["dices"] = "rbxassetid://10723343321",
 ["diff"] = "rbxassetid://10723343416",
 ["disc"] = "rbxassetid://10723343537",
 ["divide"] = "rbxassetid://10723343805",
 ["divide-circle"] = "rbxassetid://10723343636",
 ["divide-square"] = "rbxassetid://10723343737",
 ["dollar-sign"] = "rbxassetid://10723343958",
 ["download"] = "rbxassetid://10723344270",
 ["download-cloud"] = "rbxassetid://10723344088",
 ["droplet"] = "rbxassetid://10723344432",
 ["droplets"] = "rbxassetid://10734883356",
 ["drumstick"] = "rbxassetid://10723344737",
 ["edit"] = "rbxassetid://10734883598",
 ["edit-2"] = "rbxassetid://10723344885",
 ["edit-3"] = "rbxassetid://10723345088",
 ["egg"] = "rbxassetid://10723345518",
 ["egg-fried"] = "rbxassetid://10723345347",
 ["electricity"] = "rbxassetid://10723345749",
 ["electricity-off"] = "rbxassetid://10723345643",
 ["equal"] = "rbxassetid://10723345990",
 ["equal-not"] = "rbxassetid://10723345866",
 ["eraser"] = "rbxassetid://10723346158",
 ["euro"] = "rbxassetid://10723346372",
 ["expand"] = "rbxassetid://10723346553",
 ["external-link"] = "rbxassetid://10723346684",
 ["eye"] = "rbxassetid://10723346959",
 ["eye-off"] = "rbxassetid://10723346871",
 ["factory"] = "rbxassetid://10723347051",
 ["fan"] = "rbxassetid://10723354359",
 ["fast-forward"] = "rbxassetid://10723354521",
 ["feather"] = "rbxassetid://10723354671",
 ["figma"] = "rbxassetid://10723354801",
 ["file"] = "rbxassetid://10723374641",
 ["file-archive"] = "rbxassetid://10723354921",
 ["file-audio"] = "rbxassetid://10723355148",
 ["file-audio-2"] = "rbxassetid://10723355026",
 ["file-axis-3d"] = "rbxassetid://10723355272",
 ["file-badge"] = "rbxassetid://10723355622",
 ["file-badge-2"] = "rbxassetid://10723355451",
 ["file-bar-chart"] = "rbxassetid://10723355887",
 ["file-bar-chart-2"] = "rbxassetid://10723355746",
 ["file-box"] = "rbxassetid://10723355989",
 ["file-check"] = "rbxassetid://10723356210",
 ["file-check-2"] = "rbxassetid://10723356100",
 ["file-clock"] = "rbxassetid://10723356329",
 ["file-code"] = "rbxassetid://10723356507",
 ["file-cog"] = "rbxassetid://10723356830",
 ["file-cog-2"] = "rbxassetid://10723356676",
 ["file-diff"] = "rbxassetid://10723357039",
 ["file-digit"] = "rbxassetid://10723357151",
 ["file-down"] = "rbxassetid://10723357322",
 ["file-edit"] = "rbxassetid://10723357495",
 ["file-heart"] = "rbxassetid://10723357637",
 ["file-image"] = "rbxassetid://10723357790",
 ["file-input"] = "rbxassetid://10723357933",
 ["file-json"] = "rbxassetid://10723364435",
 ["file-json-2"] = "rbxassetid://10723364361",
 ["file-key"] = "rbxassetid://10723364605",
 ["file-key-2"] = "rbxassetid://10723364515",
 ["file-line-chart"] = "rbxassetid://10723364725",
 ["file-lock"] = "rbxassetid://10723364957",
 ["file-lock-2"] = "rbxassetid://10723364861",
 ["file-minus"] = "rbxassetid://10723365254",
 ["file-minus-2"] = "rbxassetid://10723365086",
 ["file-output"] = "rbxassetid://10723365457",
 ["file-pie-chart"] = "rbxassetid://10723365598",
 ["file-plus"] = "rbxassetid://10723365877",
 ["file-plus-2"] = "rbxassetid://10723365766",
 ["file-question"] = "rbxassetid://10723365987",
 ["file-scan"] = "rbxassetid://10723366167",
 ["file-search"] = "rbxassetid://10723366550",
 ["file-search-2"] = "rbxassetid://10723366340",
 ["file-signature"] = "rbxassetid://10723366741",
 ["file-spreadsheet"] = "rbxassetid://10723366962",
 ["file-symlink"] = "rbxassetid://10723367098",
 ["file-terminal"] = "rbxassetid://10723367244",
 ["file-text"] = "rbxassetid://10723367380",
 ["file-type"] = "rbxassetid://10723367606",
 ["file-type-2"] = "rbxassetid://10723367509",
 ["file-up"] = "rbxassetid://10723367734",
 ["file-video"] = "rbxassetid://10723373884",
 ["file-video-2"] = "rbxassetid://10723367834",
 ["file-volume"] = "rbxassetid://10723374172",
 ["file-volume-2"] = "rbxassetid://10723374030",
 ["file-warning"] = "rbxassetid://10723374276",
 ["file-x"] = "rbxassetid://10723374544",
 ["file-x-2"] = "rbxassetid://10723374378",
 ["files"] = "rbxassetid://10723374759",
 ["film"] = "rbxassetid://10723374981",
 ["filter"] = "rbxassetid://10723375128",
 ["fingerprint"] = "rbxassetid://10723375250",
 ["flag"] = "rbxassetid://10723375890",
 ["flag-off"] = "rbxassetid://10723375443",
 ["flag-triangle-left"] = "rbxassetid://10723375608",
 ["flag-triangle-right"] = "rbxassetid://10723375727",
 ["flame"] = "rbxassetid://10723376114",
 ["flashlight"] = "rbxassetid://10723376471",
 ["flashlight-off"] = "rbxassetid://10723376365",
 ["flask-conical"] = "rbxassetid://10734883986",
 ["flask-round"] = "rbxassetid://10723376614",
 ["flip-horizontal"] = "rbxassetid://10723376884",
 ["flip-horizontal-2"] = "rbxassetid://10723376745",
 ["flip-vertical"] = "rbxassetid://10723377138",
 ["flip-vertical-2"] = "rbxassetid://10723377026",
 ["flower"] = "rbxassetid://10747830374",
 ["flower-2"] = "rbxassetid://10723377305",
 ["focus"] = "rbxassetid://10723377537",
 ["folder"] = "rbxassetid://10723387563",
 ["folder-archive"] = "rbxassetid://10723384478",
 ["folder-check"] = "rbxassetid://10723384605",
 ["folder-clock"] = "rbxassetid://10723384731",
 ["folder-closed"] = "rbxassetid://10723384893",
 ["folder-cog"] = "rbxassetid://10723385213",
 ["folder-cog-2"] = "rbxassetid://10723385036",
 ["folder-down"] = "rbxassetid://10723385338",
 ["folder-edit"] = "rbxassetid://10723385445",
 ["folder-heart"] = "rbxassetid://10723385545",
 ["folder-input"] = "rbxassetid://10723385721",
 ["folder-key"] = "rbxassetid://10723385848",
 ["folder-lock"] = "rbxassetid://10723386005",
 ["folder-minus"] = "rbxassetid://10723386127",
 ["folder-open"] = "rbxassetid://10723386277",
 ["folder-output"] = "rbxassetid://10723386386",
 ["folder-plus"] = "rbxassetid://10723386531",
 ["folder-search"] = "rbxassetid://10723386787",
 ["folder-search-2"] = "rbxassetid://10723386674",
 ["folder-symlink"] = "rbxassetid://10723386930",
 ["folder-tree"] = "rbxassetid://10723387085",
 ["folder-up"] = "rbxassetid://10723387265",
 ["folder-x"] = "rbxassetid://10723387448",
 ["folders"] = "rbxassetid://10723387721",
 ["form-input"] = "rbxassetid://10723387841",
 ["forward"] = "rbxassetid://10723388016",
 ["frame"] = "rbxassetid://10723394389",
 ["framer"] = "rbxassetid://10723394565",
 ["frown"] = "rbxassetid://10723394681",
 ["fuel"] = "rbxassetid://10723394846",
 ["function-square"] = "rbxassetid://10723395041",
 ["gamepad"] = "rbxassetid://10723395457",
 ["gamepad-2"] = "rbxassetid://10723395215",
 ["gauge"] = "rbxassetid://10723395708",
 ["gavel"] = "rbxassetid://10723395896",
 ["gem"] = "rbxassetid://10723396000",
 ["ghost"] = "rbxassetid://10723396107",
 ["gift"] = "rbxassetid://10723396402",
 ["gift-card"] = "rbxassetid://10723396225",
 ["git-branch"] = "rbxassetid://10723396676",
 ["git-branch-plus"] = "rbxassetid://10723396542",
 ["git-commit"] = "rbxassetid://10723396812",
 ["git-compare"] = "rbxassetid://10723396954",
 ["git-fork"] = "rbxassetid://10723397049",
 ["git-merge"] = "rbxassetid://10723397165",
 ["git-pull-request"] = "rbxassetid://10723397431",
 ["git-pull-request-closed"] = "rbxassetid://10723397268",
 ["git-pull-request-draft"] = "rbxassetid://10734884302",
 ["glass"] = "rbxassetid://10723397788",
 ["glass-2"] = "rbxassetid://10723397529",
 ["glass-water"] = "rbxassetid://10723397678",
 ["glasses"] = "rbxassetid://10723397895",
 ["globe"] = "rbxassetid://10723404337",
 ["globe-2"] = "rbxassetid://10723398002",
 ["grab"] = "rbxassetid://10723404472",
 ["graduation-cap"] = "rbxassetid://10723404691",
 ["grape"] = "rbxassetid://10723404822",
 ["grid"] = "rbxassetid://10723404936",
 ["grip-horizontal"] = "rbxassetid://10723405089",
 ["grip-vertical"] = "rbxassetid://10723405236",
 ["hammer"] = "rbxassetid://10723405360",
 ["hand"] = "rbxassetid://10723405649",
 ["hand-metal"] = "rbxassetid://10723405508",
 ["hard-drive"] = "rbxassetid://10723405749",
 ["hard-hat"] = "rbxassetid://10723405859",
 ["hash"] = "rbxassetid://10723405975",
 ["haze"] = "rbxassetid://10723406078",
 ["headphones"] = "rbxassetid://10723406165",
 ["heart"] = "rbxassetid://10723406885",
 ["heart-crack"] = "rbxassetid://10723406299",
 ["heart-handshake"] = "rbxassetid://10723406480",
 ["heart-off"] = "rbxassetid://10723406662",
 ["heart-pulse"] = "rbxassetid://10723406795",
 ["help-circle"] = "rbxassetid://10723406988",
 ["hexagon"] = "rbxassetid://10723407092",
 ["highlighter"] = "rbxassetid://10723407192",
 ["history"] = "rbxassetid://10723407335",
 ["home"] = "rbxassetid://10723407389",
 ["hourglass"] = "rbxassetid://10723407498",
 ["ice-cream"] = "rbxassetid://10723414308",
 ["image"] = "rbxassetid://10723415040",
 ["image-minus"] = "rbxassetid://10723414487",
 ["image-off"] = "rbxassetid://10723414677",
 ["image-plus"] = "rbxassetid://10723414827",
 ["import"] = "rbxassetid://10723415205",
 ["inbox"] = "rbxassetid://10723415335",
 ["indent"] = "rbxassetid://10723415494",
 ["indian-rupee"] = "rbxassetid://10723415642",
 ["infinity"] = "rbxassetid://10723415766",
 ["info"] = "rbxassetid://10723415903",
 ["inspect"] = "rbxassetid://10723416057",
 ["italic"] = "rbxassetid://10723416195",
 ["japanese-yen"] = "rbxassetid://10723416363",
 ["joystick"] = "rbxassetid://10723416527",
 ["key"] = "rbxassetid://10723416652",
 ["keyboard"] = "rbxassetid://10723416765",
 ["lamp"] = "rbxassetid://10723417513",
 ["lamp-ceiling"] = "rbxassetid://10723416922",
 ["lamp-desk"] = "rbxassetid://10723417016",
 ["lamp-floor"] = "rbxassetid://10723417131",
 ["lamp-wall-down"] = "rbxassetid://10723417240",
 ["lamp-wall-up"] = "rbxassetid://10723417356",
 ["landmark"] = "rbxassetid://10723417608",
 ["languages"] = "rbxassetid://10723417703",
 ["laptop"] = "rbxassetid://10723423881",
 ["laptop-2"] = "rbxassetid://10723417797",
 ["lasso"] = "rbxassetid://10723424235",
 ["lasso-select"] = "rbxassetid://10723424058",
 ["laugh"] = "rbxassetid://10723424372",
 ["layers"] = "rbxassetid://10723424505",
 ["layout"] = "rbxassetid://10723425376",
 ["layout-dashboard"] = "rbxassetid://10723424646",
 ["layout-grid"] = "rbxassetid://10723424838",
 ["layout-list"] = "rbxassetid://10723424963",
 ["layout-template"] = "rbxassetid://10723425187",
 ["leaf"] = "rbxassetid://10723425539",
 ["library"] = "rbxassetid://10723425615",
 ["life-buoy"] = "rbxassetid://10723425685",
 ["lightbulb"] = "rbxassetid://10723425852",
 ["lightbulb-off"] = "rbxassetid://10723425762",
 ["line-chart"] = "rbxassetid://10723426393",
 ["link"] = "rbxassetid://10723426722",
 ["link-2"] = "rbxassetid://10723426595",
 ["link-2-off"] = "rbxassetid://10723426513",
 ["list"] = "rbxassetid://10723433811",
 ["list-checks"] = "rbxassetid://10734884548",
 ["list-end"] = "rbxassetid://10723426886",
 ["list-minus"] = "rbxassetid://10723426986",
 ["list-music"] = "rbxassetid://10723427081",
 ["list-ordered"] = "rbxassetid://10723427199",
 ["list-plus"] = "rbxassetid://10723427334",
 ["list-start"] = "rbxassetid://10723427494",
 ["list-video"] = "rbxassetid://10723427619",
 ["list-x"] = "rbxassetid://10723433655",
 ["loader"] = "rbxassetid://10723434070",
 ["loader-2"] = "rbxassetid://10723433935",
 ["locate"] = "rbxassetid://10723434557",
 ["locate-fixed"] = "rbxassetid://10723434236",
 ["locate-off"] = "rbxassetid://10723434379",
 ["lock"] = "rbxassetid://10723434711",
 ["log-in"] = "rbxassetid://10723434830",
 ["log-out"] = "rbxassetid://10723434906",
 ["luggage"] = "rbxassetid://10723434993",
 ["magnet"] = "rbxassetid://10723435069",
 ["mail"] = "rbxassetid://10734885430",
 ["mail-check"] = "rbxassetid://10723435182",
 ["mail-minus"] = "rbxassetid://10723435261",
 ["mail-open"] = "rbxassetid://10723435342",
 ["mail-plus"] = "rbxassetid://10723435443",
 ["mail-question"] = "rbxassetid://10723435515",
 ["mail-search"] = "rbxassetid://10734884739",
 ["mail-warning"] = "rbxassetid://10734885015",
 ["mail-x"] = "rbxassetid://10734885247",
 ["mails"] = "rbxassetid://10734885614",
 ["map"] = "rbxassetid://10734886202",
 ["map-pin"] = "rbxassetid://10734886004",
 ["map-pin-off"] = "rbxassetid://10734885803",
 ["maximize"] = "rbxassetid://10734886735",
 ["maximize-2"] = "rbxassetid://10734886496",
 ["medal"] = "rbxassetid://10734887072",
 ["megaphone"] = "rbxassetid://10734887454",
 ["megaphone-off"] = "rbxassetid://10734887311",
 ["meh"] = "rbxassetid://10734887603",
 ["menu"] = "rbxassetid://10734887784",
 ["message-circle"] = "rbxassetid://10734888000",
 ["message-square"] = "rbxassetid://10734888228",
 ["mic"] = "rbxassetid://10734888864",
 ["mic-2"] = "rbxassetid://10734888430",
 ["mic-off"] = "rbxassetid://10734888646",
 ["microscope"] = "rbxassetid://10734889106",
 ["microwave"] = "rbxassetid://10734895076",
 ["milestone"] = "rbxassetid://10734895310",
 ["minimize"] = "rbxassetid://10734895698",
 ["minimize-2"] = "rbxassetid://10734895530",
 ["minus"] = "rbxassetid://10734896206",
 ["minus-circle"] = "rbxassetid://10734895856",
 ["minus-square"] = "rbxassetid://10734896029",
 ["monitor"] = "rbxassetid://10734896881",
 ["monitor-off"] = "rbxassetid://10734896360",
 ["monitor-speaker"] = "rbxassetid://10734896512",
 ["moon"] = "rbxassetid://10734897102",
 ["more-horizontal"] = "rbxassetid://10734897250",
 ["more-vertical"] = "rbxassetid://10734897387",
 ["mountain"] = "rbxassetid://10734897956",
 ["mountain-snow"] = "rbxassetid://10734897665",
 ["mouse"] = "rbxassetid://10734898592",
 ["mouse-pointer"] = "rbxassetid://10734898476",
 ["mouse-pointer-2"] = "rbxassetid://10734898194",
 ["mouse-pointer-click"] = "rbxassetid://10734898355",
 ["move"] = "rbxassetid://10734900011",
 ["move-3d"] = "rbxassetid://10734898756",
 ["move-diagonal"] = "rbxassetid://10734899164",
 ["move-diagonal-2"] = "rbxassetid://10734898934",
 ["move-horizontal"] = "rbxassetid://10734899414",
 ["move-vertical"] = "rbxassetid://10734899821",
 ["music"] = "rbxassetid://10734905958",
 ["music-2"] = "rbxassetid://10734900215",
 ["music-3"] = "rbxassetid://10734905665",
 ["music-4"] = "rbxassetid://10734905823",
 ["navigation"] = "rbxassetid://10734906744",
 ["navigation-2"] = "rbxassetid://10734906332",
 ["navigation-2-off"] = "rbxassetid://10734906144",
 ["navigation-off"] = "rbxassetid://10734906580",
 ["network"] = "rbxassetid://10734906975",
 ["newspaper"] = "rbxassetid://10734907168",
 ["octagon"] = "rbxassetid://10734907361",
 ["option"] = "rbxassetid://10734907649",
 ["outdent"] = "rbxassetid://10734907933",
 ["package"] = "rbxassetid://10734909540",
 ["package-2"] = "rbxassetid://10734908151",
 ["package-check"] = "rbxassetid://10734908384",
 ["package-minus"] = "rbxassetid://10734908626",
 ["package-open"] = "rbxassetid://10734908793",
 ["package-plus"] = "rbxassetid://10734909016",
 ["package-search"] = "rbxassetid://10734909196",
 ["package-x"] = "rbxassetid://10734909375",
 ["paint-bucket"] = "rbxassetid://10734909847",
 ["paintbrush"] = "rbxassetid://10734910187",
 ["paintbrush-2"] = "rbxassetid://10734910030",
 ["palette"] = "rbxassetid://10734910430",
 ["palmtree"] = "rbxassetid://10734910680",
 ["paperclip"] = "rbxassetid://10734910927",
 ["party-popper"] = "rbxassetid://10734918735",
 ["pause"] = "rbxassetid://10734919336",
 ["pause-circle"] = "rbxassetid://10735024209",
 ["pause-octagon"] = "rbxassetid://10734919143",
 ["pen-tool"] = "rbxassetid://10734919503",
 ["pencil"] = "rbxassetid://10734919691",
 ["percent"] = "rbxassetid://10734919919",
 ["person-standing"] = "rbxassetid://10734920149",
 ["phone"] = "rbxassetid://10734921524",
 ["phone-call"] = "rbxassetid://10734920305",
 ["phone-forwarded"] = "rbxassetid://10734920508",
 ["phone-incoming"] = "rbxassetid://10734920694",
 ["phone-missed"] = "rbxassetid://10734920845",
 ["phone-off"] = "rbxassetid://10734921077",
 ["phone-outgoing"] = "rbxassetid://10734921288",
 ["pie-chart"] = "rbxassetid://10734921727",
 ["piggy-bank"] = "rbxassetid://10734921935",
 ["pin"] = "rbxassetid://10734922324",
 ["pin-off"] = "rbxassetid://10734922180",
 ["pipette"] = "rbxassetid://10734922497",
 ["pizza"] = "rbxassetid://10734922774",
 ["plane"] = "rbxassetid://10734922971",
 ["play"] = "rbxassetid://10734923549",
 ["play-circle"] = "rbxassetid://10734923214",
 ["plus"] = "rbxassetid://10734924532",
 ["plus-circle"] = "rbxassetid://10734923868",
 ["plus-square"] = "rbxassetid://10734924219",
 ["podcast"] = "rbxassetid://10734929553",
 ["pointer"] = "rbxassetid://10734929723",
 ["pound-sterling"] = "rbxassetid://10734929981",
 ["power"] = "rbxassetid://10734930466",
 ["power-off"] = "rbxassetid://10734930257",
 ["printer"] = "rbxassetid://10734930632",
 ["puzzle"] = "rbxassetid://10734930886",
 ["quote"] = "rbxassetid://10734931234",
 ["radio"] = "rbxassetid://10734931596",
 ["radio-receiver"] = "rbxassetid://10734931402",
 ["rectangle-horizontal"] = "rbxassetid://10734931777",
 ["rectangle-vertical"] = "rbxassetid://10734932081",
 ["recycle"] = "rbxassetid://10734932295",
 ["redo"] = "rbxassetid://10734932822",
 ["redo-2"] = "rbxassetid://10734932586",
 ["refresh-ccw"] = "rbxassetid://10734933056",
 ["refresh-cw"] = "rbxassetid://10734933222",
 ["refrigerator"] = "rbxassetid://10734933465",
 ["regex"] = "rbxassetid://10734933655",
 ["repeat"] = "rbxassetid://10734933966",
 ["repeat-1"] = "rbxassetid://10734933826",
 ["reply"] = "rbxassetid://10734934252",
 ["reply-all"] = "rbxassetid://10734934132",
 ["rewind"] = "rbxassetid://10734934347",
 ["rocket"] = "rbxassetid://10734934585",
 ["rocking-chair"] = "rbxassetid://10734939942",
 ["rotate-3d"] = "rbxassetid://10734940107",
 ["rotate-ccw"] = "rbxassetid://10734940376",
 ["rotate-cw"] = "rbxassetid://10734940654",
 ["rss"] = "rbxassetid://10734940825",
 ["ruler"] = "rbxassetid://10734941018",
 ["russian-ruble"] = "rbxassetid://10734941199",
 ["sailboat"] = "rbxassetid://10734941354",
 ["save"] = "rbxassetid://10734941499",
 ["scale"] = "rbxassetid://10734941912",
 ["scale-3d"] = "rbxassetid://10734941739",
 ["scaling"] = "rbxassetid://10734942072",
 ["scan"] = "rbxassetid://10734942565",
 ["scan-face"] = "rbxassetid://10734942198",
 ["scan-line"] = "rbxassetid://10734942351",
 ["scissors"] = "rbxassetid://10734942778",
 ["screen-share"] = "rbxassetid://10734943193",
 ["screen-share-off"] = "rbxassetid://10734942967",
 ["scroll"] = "rbxassetid://10734943448",
 ["search"] = "rbxassetid://10734943674",
 ["send"] = "rbxassetid://10734943902",
 ["separator-horizontal"] = "rbxassetid://10734944115",
 ["separator-vertical"] = "rbxassetid://10734944326",
 ["server"] = "rbxassetid://10734949856",
 ["server-cog"] = "rbxassetid://10734944444",
 ["server-crash"] = "rbxassetid://10734944554",
 ["server-off"] = "rbxassetid://10734944668",
 ["settings"] = "rbxassetid://10734950309",
 ["settings-2"] = "rbxassetid://10734950020",
 ["share"] = "rbxassetid://10734950813",
 ["share-2"] = "rbxassetid://10734950553",
 ["sheet"] = "rbxassetid://10734951038",
 ["shield"] = "rbxassetid://10734951847",
 ["shield-alert"] = "rbxassetid://10734951173",
 ["shield-check"] = "rbxassetid://10734951367",
 ["shield-close"] = "rbxassetid://10734951535",
 ["shield-off"] = "rbxassetid://10734951684",
 ["shirt"] = "rbxassetid://10734952036",
 ["shopping-bag"] = "rbxassetid://10734952273",
 ["shopping-cart"] = "rbxassetid://10734952479",
 ["shovel"] = "rbxassetid://10734952773",
 ["shower-head"] = "rbxassetid://10734952942",
 ["shrink"] = "rbxassetid://10734953073",
 ["shrub"] = "rbxassetid://10734953241",
 ["shuffle"] = "rbxassetid://10734953451",
 ["sidebar"] = "rbxassetid://10734954301",
 ["sidebar-close"] = "rbxassetid://10734953715",
 ["sidebar-open"] = "rbxassetid://10734954000",
 ["sigma"] = "rbxassetid://10734954538",
 ["signal"] = "rbxassetid://10734961133",
 ["signal-high"] = "rbxassetid://10734954807",
 ["signal-low"] = "rbxassetid://10734955080",
 ["signal-medium"] = "rbxassetid://10734955336",
 ["signal-zero"] = "rbxassetid://10734960878",
 ["siren"] = "rbxassetid://10734961284",
 ["skip-back"] = "rbxassetid://10734961526",
 ["skip-forward"] = "rbxassetid://10734961809",
 ["skull"] = "rbxassetid://10734962068",
 ["slack"] = "rbxassetid://10734962339",
 ["slash"] = "rbxassetid://10734962600",
 ["slice"] = "rbxassetid://10734963024",
 ["sliders"] = "rbxassetid://10734963400",
 ["sliders-horizontal"] = "rbxassetid://10734963191",
 ["smartphone"] = "rbxassetid://10734963940",
 ["smartphone-charging"] = "rbxassetid://10734963671",
 ["smile"] = "rbxassetid://10734964441",
 ["smile-plus"] = "rbxassetid://10734964188",
 ["snowflake"] = "rbxassetid://10734964600",
 ["sofa"] = "rbxassetid://10734964852",
 ["sort-asc"] = "rbxassetid://10734965115",
 ["sort-desc"] = "rbxassetid://10734965287",
 ["speaker"] = "rbxassetid://10734965419",
 ["sprout"] = "rbxassetid://10734965572",
 ["square"] = "rbxassetid://10734965702",
 ["star"] = "rbxassetid://10734966248",
 ["star-half"] = "rbxassetid://10734965897",
 ["star-off"] = "rbxassetid://10734966097",
 ["stethoscope"] = "rbxassetid://10734966384",
 ["sticker"] = "rbxassetid://10734972234",
 ["sticky-note"] = "rbxassetid://10734972463",
 ["stop-circle"] = "rbxassetid://10734972621",
 ["stretch-horizontal"] = "rbxassetid://10734972862",
 ["stretch-vertical"] = "rbxassetid://10734973130",
 ["strikethrough"] = "rbxassetid://10734973290",
 ["subscript"] = "rbxassetid://10734973457",
 ["sun"] = "rbxassetid://10734974297",
 ["sun-dim"] = "rbxassetid://10734973645",
 ["sun-medium"] = "rbxassetid://10734973778",
 ["sun-moon"] = "rbxassetid://10734973999",
 ["sun-snow"] = "rbxassetid://10734974130",
 ["sunrise"] = "rbxassetid://10734974522",
 ["sunset"] = "rbxassetid://10734974689",
 ["superscript"] = "rbxassetid://10734974850",
 ["swiss-franc"] = "rbxassetid://10734975024",
 ["switch-camera"] = "rbxassetid://10734975214",
 ["sword"] = "rbxassetid://10734975486",
 ["swords"] = "rbxassetid://10734975692",
 ["syringe"] = "rbxassetid://10734975932",
 ["table"] = "rbxassetid://10734976230",
 ["table-2"] = "rbxassetid://10734976097",
 ["tablet"] = "rbxassetid://10734976394",
 ["tag"] = "rbxassetid://10734976528",
 ["tags"] = "rbxassetid://10734976739",
 ["target"] = "rbxassetid://10734977012",
 ["tent"] = "rbxassetid://10734981750",
 ["terminal"] = "rbxassetid://10734982144",
 ["terminal-square"] = "rbxassetid://10734981995",
 ["text-cursor"] = "rbxassetid://10734982395",
 ["text-cursor-input"] = "rbxassetid://10734982297",
 ["thermometer"] = "rbxassetid://10734983134",
 ["thermometer-snowflake"] = "rbxassetid://10734982571",
 ["thermometer-sun"] = "rbxassetid://10734982771",
 ["thumbs-down"] = "rbxassetid://10734983359",
 ["thumbs-up"] = "rbxassetid://10734983629",
 ["ticket"] = "rbxassetid://10734983868",
 ["timer"] = "rbxassetid://10734984606",
 ["timer-off"] = "rbxassetid://10734984138",
 ["timer-reset"] = "rbxassetid://10734984355",
 ["toggle-left"] = "rbxassetid://10734984834",
 ["toggle-right"] = "rbxassetid://10734985040",
 ["tornado"] = "rbxassetid://10734985247",
 ["toy-brick"] = "rbxassetid://10747361919",
 ["train"] = "rbxassetid://10747362105",
 ["trash"] = "rbxassetid://10747362393",
 ["trash-2"] = "rbxassetid://10747362241",
 ["tree-deciduous"] = "rbxassetid://10747362534",
 ["tree-pine"] = "rbxassetid://10747362748",
 ["trees"] = "rbxassetid://10747363016",
 ["trending-down"] = "rbxassetid://10747363205",
 ["trending-up"] = "rbxassetid://10747363465",
 ["triangle"] = "rbxassetid://10747363621",
 ["trophy"] = "rbxassetid://10747363809",
 ["truck"] = "rbxassetid://10747364031",
 ["tv"] = "rbxassetid://10747364593",
 ["tv-2"] = "rbxassetid://10747364302",
 ["type"] = "rbxassetid://10747364761",
 ["umbrella"] = "rbxassetid://10747364971",
 ["underline"] = "rbxassetid://10747365191",
 ["undo"] = "rbxassetid://10747365484",
 ["undo-2"] = "rbxassetid://10747365359",
 ["unlink"] = "rbxassetid://10747365771",
 ["unlink-2"] = "rbxassetid://10747397871",
 ["unlock"] = "rbxassetid://10747366027",
 ["upload"] = "rbxassetid://10747366434",
 ["upload-cloud"] = "rbxassetid://10747366266",
 ["usb"] = "rbxassetid://10747366606",
 ["user"] = "rbxassetid://10747373176",
 ["user-check"] = "rbxassetid://10747371901",
 ["user-cog"] = "rbxassetid://10747372167",
 ["user-minus"] = "rbxassetid://10747372346",
 ["user-plus"] = "rbxassetid://10747372702",
 ["user-x"] = "rbxassetid://10747372992",
 ["users"] = "rbxassetid://10747373426",
 ["utensils"] = "rbxassetid://10747373821",
 ["utensils-crossed"] = "rbxassetid://10747373629",
 ["venetian-mask"] = "rbxassetid://10747374003",
 ["verified"] = "rbxassetid://10747374131",
 ["vibrate"] = "rbxassetid://10747374489",
 ["vibrate-off"] = "rbxassetid://10747374269",
 ["video"] = "rbxassetid://10747374938",
 ["video-off"] = "rbxassetid://10747374721",
 ["view"] = "rbxassetid://10747375132",
 ["voicemail"] = "rbxassetid://10747375281",
 ["volume"] = "rbxassetid://10747376008",
 ["volume-1"] = "rbxassetid://10747375450",
 ["volume-2"] = "rbxassetid://10747375679",
 ["volume-x"] = "rbxassetid://10747375880",
 ["wallet"] = "rbxassetid://10747376205",
 ["wand"] = "rbxassetid://10747376565",
 ["wand-2"] = "rbxassetid://10747376349",
 ["watch"] = "rbxassetid://10747376722",
 ["waves"] = "rbxassetid://10747376931",
 ["webcam"] = "rbxassetid://10747381992",
 ["wifi"] = "rbxassetid://10747382504",
 ["wifi-off"] = "rbxassetid://10747382268",
 ["wind"] = "rbxassetid://10747382750",
 ["wrap-text"] = "rbxassetid://10747383065",
 ["wrench"] = "rbxassetid://10747383470",
 ["x"] = "rbxassetid://10747384394",
 ["x-circle"] = "rbxassetid://10747383819",
 ["x-octagon"] = "rbxassetid://10747384037",
 ["x-square"] = "rbxassetid://10747384217",
 ["zoom-in"] = "rbxassetid://10747384552",
 ["zoom-out"] = "rbxassetid://10747384679",
}
Prism.Icons = Icons

local function resolveIcon(name)
 if not name then return nil end
 return Icons[name] or (string.find(name, "rbxasset") and name) or nil
end

-- ============================================================================
-- HELPERS
-- ============================================================================
local function new(class, props, children)
 local inst = Instance.new(class)
 for k, v in pairs(props or {}) do
 if k ~= "Parent" then inst[k] = v end
 end
 for _, child in ipairs(children or {}) do
 child.Parent = inst
 end
 if props and props.Parent then inst.Parent = props.Parent end
 return inst
end

local function corner(r)
 return new("UICorner", { CornerRadius = r == "full" and UDim.new(1, 0) or UDim.new(0, r) })
end

local function stroke(color, thickness, transparency)
 return new("UIStroke", {
 Color = color or Theme.Stroke,
 Thickness = thickness or 1,
 Transparency = transparency or 0,
 ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
 })
end

-- The standard hairline outline.
local function outline(transparency)
 return stroke(Theme.Outline, 1, transparency or Theme.OutlineTransparency)
end

local function padding(t, b, l, r)
 return new("UIPadding", {
 PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b or t),
 PaddingLeft = UDim.new(0, l or t), PaddingRight = UDim.new(0, r or l or t),
 })
end

local function tween(obj, time, props, style, dir)
 local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
 tw:Play()
 return tw
end

local function lerp(a, b, t) return a + (b - a) * t end

local function icon(name, size, color, props)
 local img = new("ImageLabel", {
 Size = UDim2.fromOffset(size, size),
 BackgroundTransparency = 1,
 Image = resolveIcon(name) or "",
 ImageColor3 = color or Theme.SubText,
 })
 for k, v in pairs(props or {}) do
 if k ~= "Parent" then img[k] = v end
 end
 if props and props.Parent then img.Parent = props.Parent end
 return img
end

-- Soft 9-slice drop shadow. "Window" for the big one, "Popup" for cards.
local function dropShadow(parent, kind)
 if kind == "Window" then
 return new("ImageLabel", {
 Name = "Shadow",
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.new(1, 120, 1, 116),
 BackgroundTransparency = 1,
 Image = "rbxassetid://8992230677",
 ScaleType = Enum.ScaleType.Slice,
 SliceCenter = Rect.new(99, 99, 99, 99),
 ImageColor3 = Color3.new(0, 0, 0),
 ImageTransparency = 0.4,
 Parent = parent,
 })
 end
 return new("ImageLabel", {
 Name = "Shadow",
 Position = UDim2.fromOffset(-15, -15),
 Size = UDim2.new(1, 30, 1, 30),
 BackgroundTransparency = 1,
 Image = "rbxassetid://5554236805",
 ScaleType = Enum.ScaleType.Slice,
 SliceCenter = Rect.new(23, 23, 277, 277),
 ImageColor3 = Color3.new(0, 0, 0),
 ImageTransparency = 0.5,
 Parent = parent,
 })
end

-- Soft coloured glow behind a control, made from the popup shadow image.
-- spread: how far it reaches past the target's edges.
local function softGlow(parent, target, spread, transparency)
 return new("ImageLabel", {
 Name = "Glow",
 AnchorPoint = target.AnchorPoint,
 Position = target.Position,
 Size = target.Size + UDim2.fromOffset(spread * 2, spread * 2),
 BackgroundTransparency = 1,
 Image = "rbxassetid://5554236805",
 ScaleType = Enum.ScaleType.Slice,
 SliceCenter = Rect.new(23, 23, 277, 277),
 ImageColor3 = Theme.Accent,
 ImageTransparency = transparency or 1,
 ZIndex = math.max(1, target.ZIndex - 1),
 Parent = parent,
 })
end

-- UI sounds use Roblox's built-in client sounds, so they always load.
local SOUND_IDS = {
 Click = "rbxasset://sounds/clickfast.wav",
 Toggle = "rbxasset://sounds/switch.wav",
 Notify = "rbxasset://sounds/electronicpingshort.wav",
}
local function playSound(name, pitch)
 if not Prism.Sounds then return end
 local sound = Instance.new("Sound")
 sound.SoundId = SOUND_IDS[name]
 sound.Volume = 0.4 * Prism.SoundVolume
 sound.PlaybackSpeed = pitch or 1
 sound.Parent = SoundService
 sound.Ended:Connect(function() sound:Destroy() end)
 sound:Play()
 task.delay(2, function() if sound.Parent then sound:Destroy() end end)
end

local function safeCall(cb, ...)
 if typeof(cb) ~= "function" then return end
 local args = table.pack(...)
 task.spawn(function()
 local ok, err = pcall(cb, table.unpack(args, 1, args.n))
 if not ok then warn("[Prism] callback error: " .. tostring(err)) end
 end)
end

local function formatNumber(v)
 if v % 1 == 0 then return tostring(v) end
 return (string.format("%.2f", v):gsub("0+$", ""))
end

-- ============================================================================
-- ACCENT
-- ============================================================================
-- Everything accent-coloured is registered here so Prism:SetAccent can
-- recolour it live.
--
-- Strong tables, pruned once an instance has left the game. Not weak keys:
-- Roblox can collect an Instance's Lua wrapper while the Instance is still
-- alive, which silently dropped entries (SetAccent missed most of the UI).
-- ============================================================================
local accentProps = {} -- [Instance] = property
local accentGradients = {} -- [UIGradient] = true
local themeListeners = {} -- [owner] = fn

local function alive(inst)
 return inst.Parent ~= nil and inst:IsDescendantOf(game)
end

local function bindAccent(inst, prop)
 accentProps[inst] = prop
 inst[prop] = Theme.Accent
 return inst
end

-- White fill + this gradient = the violet -> pink accent gradient.
local function accentGradient(parent, rotation)
 local g = Instance.new("UIGradient")
 g.Color = accentSequence()
 g.Rotation = rotation or 0
 g.Parent = parent
 accentGradients[g] = true
 return g
end

local function onThemeChanged(owner, fn)
 themeListeners[owner] = fn
end

function Prism:SetAccent(color)
 Theme.Accent = color
 for inst, prop in pairs(accentProps) do
 if alive(inst) then inst[prop] = color else accentProps[inst] = nil end
 end
 for g in pairs(accentGradients) do
 if alive(g) then g.Color = accentSequence() else accentGradients[g] = nil end
 end
 for _, fn in pairs(themeListeners) do task.spawn(fn) end
end

-- Per-frame tickers (logo shine, menu shine). Each ticker removes itself
-- once its UI is gone.
local tickers = {}

-- Library-wide connections; a re-execution disconnects the old copy's.
Prism._libConns = {}

table.insert(Prism._libConns, RunService.Heartbeat:Connect(function()
 local t = os.clock()
 for owner, fn in pairs(tickers) do
 fn(t, owner)
 end
end))

-- Every ScreenGui Prism makes goes through here, so SetTheme can find them.
Prism._roots = {}

local function guiParent(gui)
 Prism._roots[gui] = true
 local ok = pcall(function()
 gui.Parent = (gethui and gethui()) or CoreGui
 end)
 if not ok or not gui.Parent then
 gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
 end
end

-- ============================================================================
-- THEMES
-- ============================================================================
-- Full presets: every surface, input, outline and text colour, plus an
-- accent. Prism:SetTheme(name | preset) switches live.
--
-- How the live switch works: every ScreenGui Prism creates is registered
-- (see guiParent). SetTheme builds an old -> new colour map from the
-- current palette to the new one, then walks those GUIs and swaps any
-- colour property that exactly matches an old palette colour. Hover and
-- state tweens read Theme at the moment they run, so they pick up the new
-- palette on their own.
--
-- Custom preset: Prism:SetTheme({ Background = ..., Surface = ..., Accent = ... })
-- (any keys you leave out keep their current value).
-- ============================================================================
local THEME_KEYS = {
 "Background", "Surface", "Element", "ElementHover", "ElementPress",
 "Input", "Stroke", "Text", "SubText", "Muted",
}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local THEME_PRESETS = {
 {
 Name = "Prism", Accent = rgb(150, 122, 255),
 Background = rgb(12, 12, 14), Surface = rgb(17, 17, 20), Element = rgb(23, 23, 27),
 ElementHover = rgb(29, 29, 34), ElementPress = rgb(35, 35, 41), Input = rgb(14, 14, 17),
 Stroke = rgb(42, 42, 48), Text = rgb(242, 242, 245), SubText = rgb(161, 161, 170), Muted = rgb(113, 113, 122),
 },
 {
 Name = "Midnight", Accent = rgb(99, 140, 255),
 Background = rgb(9, 11, 19), Surface = rgb(13, 16, 27), Element = rgb(19, 23, 37),
 ElementHover = rgb(25, 30, 47), ElementPress = rgb(31, 37, 57), Input = rgb(8, 10, 17),
 Stroke = rgb(40, 46, 68), Text = rgb(236, 240, 252), SubText = rgb(152, 162, 190), Muted = rgb(98, 108, 138),
 },
 {
 Name = "Graphite", Accent = rgb(212, 212, 222),
 Background = rgb(24, 24, 27), Surface = rgb(31, 31, 35), Element = rgb(40, 40, 45),
 ElementHover = rgb(48, 48, 54), ElementPress = rgb(56, 56, 63), Input = rgb(20, 20, 23),
 Stroke = rgb(63, 63, 70), Text = rgb(244, 244, 245), SubText = rgb(170, 170, 178), Muted = rgb(120, 120, 130),
 },
 {
 Name = "Rosé", Accent = rgb(244, 114, 182),
 Background = rgb(17, 11, 14), Surface = rgb(24, 16, 20), Element = rgb(33, 22, 28),
 ElementHover = rgb(41, 28, 35), ElementPress = rgb(49, 34, 42), Input = rgb(14, 9, 12),
 Stroke = rgb(60, 42, 51), Text = rgb(250, 238, 243), SubText = rgb(190, 160, 172), Muted = rgb(138, 108, 120),
 },
 {
 Name = "Forest", Accent = rgb(52, 211, 153),
 Background = rgb(9, 15, 12), Surface = rgb(13, 21, 17), Element = rgb(19, 29, 24),
 ElementHover = rgb(25, 37, 31), ElementPress = rgb(31, 45, 38), Input = rgb(8, 13, 10),
 Stroke = rgb(38, 56, 47), Text = rgb(236, 248, 241), SubText = rgb(150, 180, 164), Muted = rgb(100, 130, 114),
 },
 {
 Name = "Ember", Accent = rgb(251, 146, 60),
 Background = rgb(17, 11, 9), Surface = rgb(24, 16, 13), Element = rgb(33, 22, 18),
 ElementHover = rgb(42, 28, 23), ElementPress = rgb(51, 34, 28), Input = rgb(14, 9, 7),
 Stroke = rgb(62, 42, 34), Text = rgb(250, 240, 234), SubText = rgb(192, 164, 150), Muted = rgb(140, 112, 100),
 },
 {
 Name = "Ocean", Accent = rgb(56, 189, 248),
 Background = rgb(8, 14, 19), Surface = rgb(11, 20, 27), Element = rgb(16, 28, 37),
 ElementHover = rgb(21, 35, 46), ElementPress = rgb(26, 42, 55), Input = rgb(7, 12, 16),
 Stroke = rgb(34, 52, 66), Text = rgb(234, 246, 252), SubText = rgb(150, 175, 192), Muted = rgb(98, 124, 142),
 },
 {
 Name = "AMOLED", Accent = rgb(150, 122, 255),
 Background = rgb(0, 0, 0), Surface = rgb(8, 8, 10), Element = rgb(15, 15, 18),
 ElementHover = rgb(22, 22, 26), ElementPress = rgb(29, 29, 34), Input = rgb(4, 4, 5),
 Stroke = rgb(38, 38, 44), Text = rgb(242, 242, 245), SubText = rgb(161, 161, 170), Muted = rgb(113, 113, 122),
 },
}
Prism.Themes = THEME_PRESETS
Prism.CurrentTheme = "Prism"

local function colorKey(c)
 return math.floor(c.R * 255 + 0.5) .. "," .. math.floor(c.G * 255 + 0.5) .. "," .. math.floor(c.B * 255 + 0.5)
end

-- Colour properties worth remapping, by class.
local THEMED_PROPS = {
 { "GuiObject", "BackgroundColor3" },
 { "TextLabel", "TextColor3" },
 { "TextButton", "TextColor3" },
 { "TextBox", "TextColor3" },
 { "TextBox", "PlaceholderColor3" },
 { "ImageLabel", "ImageColor3" },
 { "ImageButton", "ImageColor3" },
 { "ScrollingFrame", "ScrollBarImageColor3" },
 { "UIStroke", "Color" },
}

local function findPreset(name)
 for _, p in ipairs(THEME_PRESETS) do
 if p.Name == name then return p end
 end
end

function Prism:SetTheme(preset)
 if typeof(preset) == "string" then preset = findPreset(preset) end
 if typeof(preset) ~= "table" then return false end

 -- old -> new for every palette key the preset changes
 local map, any = {}, false
 for _, key in ipairs(THEME_KEYS) do
 local newColor = preset[key]
 if newColor and newColor ~= Theme[key] then
 map[colorKey(Theme[key])] = newColor
 any = true
 end
 end
 for _, key in ipairs(THEME_KEYS) do
 if preset[key] then Theme[key] = preset[key] end
 end

 if any then
 for gui in pairs(Prism._roots) do
 if gui.Parent then
 for _, inst in ipairs(gui:GetDescendants()) do
 for _, spec in ipairs(THEMED_PROPS) do
 if inst:IsA(spec[1]) then
 local ok, current = pcall(function() return inst[spec[2]] end)
 if ok and typeof(current) == "Color3" then
 local replacement = map[colorKey(current)]
 if replacement then inst[spec[2]] = replacement end
 end
 end
 end
 end
 else
 Prism._roots[gui] = nil
 end
 end
 end

 if preset.Accent then Prism:SetAccent(preset.Accent) end
 Prism.CurrentTheme = preset.Name or "Custom"
 return true
end

-- ============================================================================
-- FONTS
-- ============================================================================
-- Prism:SetFont(name) switches every label live, keeping each one's weight.
-- Only Roblox's built-in families, so they always load.
-- ============================================================================
local FONT_FAMILIES = {
 { "Gotham", "rbxasset://fonts/families/GothamSSm.json" },
 { "Builder Sans", "rbxasset://fonts/families/BuilderSans.json" },
 { "Montserrat", "rbxasset://fonts/families/Montserrat.json" },
 { "Roboto", "rbxasset://fonts/families/Roboto.json" },
 { "Nunito", "rbxasset://fonts/families/Nunito.json" },
 { "Ubuntu", "rbxasset://fonts/families/Ubuntu.json" },
 { "Titillium", "rbxasset://fonts/families/TitilliumWeb.json" },
 { "Roboto Mono", "rbxasset://fonts/families/RobotoMono.json" },
}
Prism.FontFamilies = FONT_FAMILIES
Prism.CurrentFont = "Gotham"

function Prism:SetFont(name)
 local family
 for _, f in ipairs(FONT_FAMILIES) do
 if f[1] == name then family = f[2] end
 end
 if not family then return false end
 local old = Fonts.Regular.Family
 if family == old then return true end

 -- Future elements
 for key, weight in pairs({
 Regular = Enum.FontWeight.Regular, Medium = Enum.FontWeight.Medium,
 SemiBold = Enum.FontWeight.SemiBold, Bold = Enum.FontWeight.Bold,
 }) do
 Fonts[key] = Font.new(family, weight)
 end
 -- Everything already on screen
 for gui in pairs(Prism._roots) do
 if gui.Parent then
 for _, inst in ipairs(gui:GetDescendants()) do
 if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
 local f = inst.FontFace
 if f.Family == old then
 inst.FontFace = Font.new(family, f.Weight, f.Style)
 end
 end
 end
 end
 end
 Prism.CurrentFont = name
 return true
end

local function isMouseOrTouch(input)
 return input.UserInputType == Enum.UserInputType.MouseButton1
 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
 return input.UserInputType == Enum.UserInputType.MouseMovement
 or input.UserInputType == Enum.UserInputType.Touch
end

-- ============================================================================
-- CRYSTAL LOGO
-- ============================================================================
-- A faceted gem seen face on: a diamond cut into eight flat-shaded facets,
-- lit from the top-left, with the spectrum running around the stone.
--
-- T
-- / | \
-- Mtl / | \ Mtr
-- / \ | / \
-- L----O----R
-- \ / | \ /
-- Mbl \ | / Mbr
-- \ | /
-- B
--
-- Every facet is a right isosceles triangle, which Roblox can draw without
-- images: a square Frame rotated into place, with a UIGradient that makes
-- the half on one side of its diagonal transparent.
--
-- Design space is 120x120. Scale it with the holder's UIScale.
-- ============================================================================
local LOGO_SIZE = 120
local LOGO_CENTER = Vector2.new(60, 60)
local LOGO_RADIUS = 54

local LOGO_FACETS = (function()
 local R, H = LOGO_RADIUS, LOGO_RADIUS / 2
 local O = Vector2.zero
 local T, Rt, B, L = Vector2.new(0, -R), Vector2.new(R, 0), Vector2.new(0, R), Vector2.new(-R, 0)
 local Mtr, Mbr, Mbl, Mtl = Vector2.new(H, -H), Vector2.new(H, H), Vector2.new(-H, H), Vector2.new(-H, -H)

 -- { hypotenuse end, hypotenuse end, right-angle corner, shade }
 -- Clockwise from the top. Order matters: it's the assembly order in the
 -- intro and the direction the idle shine travels.
 return {
 { O, T, Mtr, Color3.fromRGB(255, 150, 214) },
 { O, Rt, Mtr, Color3.fromRGB(196, 132, 255) },
 { O, Rt, Mbr, Color3.fromRGB(122, 100, 226) },
 { O, B, Mbr, Color3.fromRGB(66, 92, 198) },
 { O, B, Mbl, Color3.fromRGB(74, 150, 242) },
 { O, L, Mbl, Color3.fromRGB(98, 214, 228) },
 { O, L, Mtl, Color3.fromRGB(178, 240, 248) },
 { O, T, Mtl, Color3.fromRGB(255, 228, 246) },
 }
end)()

-- Opaque on the far side of the diagonal, transparent on the near side.
local FACET_CUT = NumberSequence.new({
 NumberSequenceKeypoint.new(0, 1),
 NumberSequenceKeypoint.new(0.497, 1),
 NumberSequenceKeypoint.new(0.503, 0),
 NumberSequenceKeypoint.new(1, 0),
})

local WHITE = Color3.new(1, 1, 1)

local function buildLogo(parent, opts)
 opts = opts or {}
 local hidden = opts.Hidden

 local holder = new("Frame", {
 Name = "PrismLogo",
 AnchorPoint = Vector2.new(0.5, 0.5),
 Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
 BackgroundTransparency = 1,
 ZIndex = opts.ZIndex or 1,
 Parent = parent,
 })
 local scale = new("UIScale", { Scale = opts.Scale or 1, Parent = holder })

 -- Idle turns on the shine and glint animation once the logo is formed.
 local logo = { Holder = holder, Scale = scale, Facets = {}, Idle = not hidden }

 -- Dark setting behind the stone. It shows through the hairline seams
 -- between facets, which read as the cut edges.
 local rimSide = (LOGO_RADIUS + 3) * math.sqrt(2)
 logo.Rim = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(LOGO_CENTER.X, LOGO_CENTER.Y),
 Size = UDim2.fromOffset(rimSide, rimSide),
 Rotation = 45,
 BackgroundColor3 = Color3.fromRGB(24, 19, 44),
 BackgroundTransparency = hidden and 1 or 0,
 BorderSizePixel = 0,
 Parent = holder,
 }, { corner(3) })

 for _, def in ipairs(LOGO_FACETS) do
 local p, q, m, color = def[1], def[2], def[3], def[4]

 -- The facet is half of the square whose diagonal is p-q and which has
 -- a corner at m. Rotate the frame so its edges run along m->p, then
 -- point the gradient (in the frame's local space) at m.
 local center = (p + q) / 2
 local edge = p - m
 local theta = math.atan2(edge.Y, edge.X)
 local toCorner = m - center
 local c, s = math.cos(-theta), math.sin(-theta)
 local localDir = Vector2.new(toCorner.X * c - toCorner.Y * s, toCorner.X * s + toCorner.Y * c)
 local home = LOGO_CENTER + center

 local frame = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(home.X, home.Y),
 Size = UDim2.fromOffset(edge.Magnitude, edge.Magnitude),
 Rotation = math.deg(theta),
 BackgroundColor3 = color,
 BackgroundTransparency = hidden and 1 or 0,
 BorderSizePixel = 0,
 Parent = holder,
 }, {
 new("UIGradient", {
 Transparency = FACET_CUT,
 Rotation = math.deg(math.atan2(localDir.Y, localDir.X)),
 }),
 })

 table.insert(logo.Facets, {
 Frame = frame,
 Home = home,
 Rotation = frame.Rotation,
 Color = color,
 Outward = center.Unit,
 })
 end

 -- Four-point glint on the top-left edge, where the light hits.
 logo.Glint = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(LOGO_CENTER.X - 26, LOGO_CENTER.Y - 26),
 Size = UDim2.fromOffset(22, 22),
 BackgroundTransparency = 1,
 ZIndex = 2,
 Parent = holder,
 }, {
 new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(3, 22), BackgroundColor3 = WHITE, BorderSizePixel = 0,
 }, { corner("full") }),
 new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(22, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0,
 }, { corner("full") }),
 new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0,
 }),
 })
 logo.GlintScale = new("UIScale", { Scale = hidden and 0 or 1, Parent = logo.Glint })

 -- Idle: every few seconds a shine sweeps round the facets clockwise, and
 -- the glint breathes.
 tickers[holder] = function(t)
 if not holder.Parent then
 tickers[holder] = nil
 return
 end
 if not logo.Idle then return end

 local cycle = t % 4.5
 local wave = cycle < 1.4 and (cycle / 1.4) * 11 - 1.5 or nil
 for i, facet in ipairs(logo.Facets) do
 local k = wave and math.max(0, 1 - math.abs(i - wave) / 1.6) or 0
 facet.Frame.BackgroundColor3 = facet.Color:Lerp(WHITE, 0.45 * k * k)
 end
 logo.GlintScale.Scale = 0.75 + 0.25 * math.sin(t * 2.4)
 end

 return logo
end

Prism.BuildLogo = buildLogo

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
-- Prism:Notify{ Title, Content, Type = "Info" | "Success" | "Warning" |
-- "Error", Icon, Duration = 4 }
-- Click a notification to dismiss it early.
-- ============================================================================
local notifyGui, notifyHolder

local NOTIFY_TYPES = {
 Info = { Icon = "info", Color = function() return Theme.Accent end },
 Success = { Icon = "check-circle", Color = function() return Theme.Success end },
 Warning = { Icon = "alert-triangle", Color = function() return Theme.Warning end },
 Error = { Icon = "x-circle", Color = function() return Theme.Error end },
 -- Spins and stays until updated or closed: handle:Update{ Type = "Success" }.
 Loading = { Icon = "loader", Color = function() return Theme.Accent end, Spin = true, Persistent = true },
}

-- Corner the stack sits in: "BottomRight" (default), "TopRight",
-- "BottomLeft" or "TopLeft".
Prism.NotifyPosition = "BottomRight"

local function placeNotifyHolder()
 local pos = Prism.NotifyPosition
 local top = string.find(pos, "Top") ~= nil
 local left = string.find(pos, "Left") ~= nil
 local inset = game:GetService("GuiService"):GetGuiInset().Y
 notifyHolder.AnchorPoint = Vector2.new(left and 0 or 1, top and 0 or 1)
 notifyHolder.Position = UDim2.new(left and 0 or 1, left and 20 or -20, top and 0 or 1, top and (inset + 16) or -20)
 notifyHolder.UIListLayout.VerticalAlignment = top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
end

function Prism:SetNotifyPosition(pos)
 Prism.NotifyPosition = pos
 if notifyHolder and notifyHolder.Parent then placeNotifyHolder() end
end

local function ensureNotifyHolder()
 if notifyHolder and notifyHolder.Parent then return notifyHolder end
 notifyGui = new("ScreenGui", {
 Name = "PrismNotifications",
 ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
 IgnoreGuiInset = true,
 ResetOnSpawn = false,
 DisplayOrder = 1000,
 })
 guiParent(notifyGui)
 notifyHolder = new("Frame", {
 AnchorPoint = Vector2.new(1, 1),
 Position = UDim2.new(1, -20, 1, -20),
 Size = UDim2.new(0, 280, 1, -40),
 BackgroundTransparency = 1,
 Parent = notifyGui,
 }, {
 new("UIListLayout", {
 Padding = UDim.new(0, 8),
 VerticalAlignment = Enum.VerticalAlignment.Bottom,
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 placeNotifyHolder()
 return notifyHolder
end

local notifyOrder = 0

-- At most this many toasts on screen; the rest wait behind a "+N more" pill
-- and slide in as earlier ones close. Click the pill to drop the queue.
Prism.MaxNotifications = 4
-- Do not disturb: toasts are skipped but still land in the history.
Prism.NotifyMuted = false
-- Every notification sent, newest last. See Prism:GetNotifications().
Prism.NotifyHistory = {}
local NOTIFY_HISTORY_MAX = 50
local activeToasts, queued, morePill = 0, {}, nil
local liveToasts = {} -- [handle] = merge key, while on screen

local function updateMorePill()
 if not (notifyHolder and notifyHolder.Parent) then return end
 if not (morePill and morePill.Parent) then
 morePill = new("TextButton", {
 Size = UDim2.new(1, 0, 0, 24),
 BackgroundColor3 = Theme.Surface,
 AutoButtonColor = false,
 FontFace = Fonts.Medium,
 Text = "",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 LayoutOrder = -1,
 Visible = false,
 Parent = notifyHolder,
 }, { corner(6), outline() })
 morePill.MouseEnter:Connect(function() tween(morePill, 0.12, { BackgroundColor3 = Theme.Element }) end)
 morePill.MouseLeave:Connect(function() tween(morePill, 0.12, { BackgroundColor3 = Theme.Surface }) end)
 morePill.MouseButton1Click:Connect(function()
 for _, h in ipairs(queued) do h._dropped = true end
 table.clear(queued)
 updateMorePill()
 end)
 end
 morePill.Visible = #queued > 0
 morePill.Text = "+" .. #queued .. " more · click to clear"
end

local function notifyKey(o)
 return tostring(o.Title) .. "\0" .. tostring(o.Content) .. "\0" .. tostring(o.Type)
end

-- Handle returned by Prism:Notify. Works before the toast is on screen
-- (queued, or waiting for the intro): changes are kept and applied on show.
-- :Update{ Title, Content, Type, Icon, Duration, Progress }
-- :SetTitle(text) :SetContent(text) :SetProgress(0..1 | false) :Close()
local Toast = {}
Toast.__index = Toast

function Toast:Update(changes)
 for k, v in pairs(changes) do self._opts[k] = v end
 if self._apply then self._apply(changes) end
 return self
end
function Toast:SetTitle(text) return self:Update({ Title = text }) end
function Toast:SetContent(text) return self:Update({ Content = text }) end
function Toast:SetProgress(p) return self:Update({ Progress = p }) end
function Toast:Close()
 if self._close then
 task.spawn(self._close)
 return
 end
 self._dropped = true
 local i = table.find(queued, self)
 if i then
 table.remove(queued, i)
 updateMorePill()
 end
end

local showToast

-- Prism:Notify{ Title, Content, Type, Icon, Duration, Buttons, Progress,
-- Callback, OnClose, Merge, Force } -> handle
-- Type: "Info" | "Success" | "Warning" | "Error" | "Loading".
-- Duration: seconds; 0 or math.huge stays until closed. Loading toasts stay
-- by default. Buttons: { { Name, Callback, Primary, KeepOpen }, ... }.
-- A repeat of a toast still on screen bumps its "x2" count instead of
-- stacking (Merge = false to opt out). Hovering pauses the timer.
function Prism:Notify(opts)
 opts = table.clone(opts or {})
 if opts.Merge ~= false then
 local key = notifyKey(opts)
 for live, k in pairs(liveToasts) do
 if k == key and live._bump then
 live._bump()
 return live
 end
 end
 end
 local handle = setmetatable({ _opts = opts }, Toast)
 local history = Prism.NotifyHistory
 table.insert(history, {
 Title = opts.Title or "Prism",
 Content = opts.Content or "",
 Type = opts.Type or "Info",
 Time = os.time(),
 })
 if #history > NOTIFY_HISTORY_MAX then table.remove(history, 1) end
 if Prism.NotifyMuted and not opts.Force then return handle end
 if Prism._introBusy then
 task.spawn(function()
 repeat task.wait(0.1) until not Prism._introBusy
 if not handle._dropped then showToast(handle) end
 end)
 return handle
 end
 showToast(handle)
 return handle
end

-- Copy of the history, newest last.
function Prism:GetNotifications()
 return table.clone(Prism.NotifyHistory)
end

-- Closes every toast on screen and drops the queue.
function Prism:ClearNotifications()
 for _, h in ipairs(queued) do h._dropped = true end
 table.clear(queued)
 updateMorePill()
 for h in pairs(liveToasts) do h:Close() end
end

showToast = function(handle)
 local opts = handle._opts
 local holder = ensureNotifyHolder()
 if activeToasts >= Prism.MaxNotifications then
 table.insert(queued, handle)
 updateMorePill()
 return
 end
 activeToasts += 1
 local kind = NOTIFY_TYPES[opts.Type or "Info"] or NOTIFY_TYPES.Info
 local color = kind.Color()
 local fromLeft = string.find(Prism.NotifyPosition, "Left") ~= nil
 local OFFSCREEN = UDim2.fromOffset(fromLeft and -360 or 360, 0)
 notifyOrder += 1
 playSound("Notify", kind == NOTIFY_TYPES.Error and 0.8 or 1)

 -- wrapper: takes the card's height in the list.
 -- mover: slides in and out, carrying the shadow, card and timer.
 local wrapper = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 LayoutOrder = notifyOrder,
 Parent = holder,
 })
 local mover = new("Frame", {
 Position = OFFSCREEN,
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Parent = wrapper,
 })
 local pop = new("UIScale", { Scale = 0.94, Parent = mover })
 dropShadow(mover, "Popup")

 local card = new("TextButton", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Surface,
 AutoButtonColor = false,
 Text = "",
 BorderSizePixel = 0,
 ClipsDescendants = true,
 Parent = mover,
 }, { corner(7), outline(), padding(10, 12, 14, 10) })

 -- Faint wash of the type colour from the left, plus a slim indicator
 -- pill. Both live in the mover, not the auto-sized card, so they can't
 -- feed back into the card's height.
 local wash = new("Frame", {
 Size = UDim2.new(0, 120, 1, 0),
 BackgroundColor3 = color,
 BackgroundTransparency = 0.93,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = mover,
 }, {
 corner(7),
 new("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
 })
 local bar = new("Frame", {
 Position = UDim2.new(0, 4, 0, 10),
 Size = UDim2.new(0, 2, 1, -20),
 BackgroundColor3 = color,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = mover,
 }, { corner("full") })

 local badge = new("Frame", {
 Size = UDim2.fromOffset(26, 26),
 BackgroundColor3 = color,
 BackgroundTransparency = 0.86,
 BorderSizePixel = 0,
 Parent = card,
 }, { corner("full") })
 local iconImg = icon(opts.Icon or kind.Icon, 14, color, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = badge,
 })

 local text = new("Frame", {
 Position = UDim2.fromOffset(36, 0),
 Size = UDim2.new(1, -56, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = card,
 }, { new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
 local titleLabel = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = "",
 RichText = true,
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 1,
 Parent = text,
 })
 local contentLabel = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Content or "",
 Visible = (opts.Content or "") ~= "",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextWrapped = true,
 RichText = true,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 2,
 Parent = text,
 })

 local closed = false
 local close -- defined below; buttons need it

 -- Action buttons
 if type(opts.Buttons) == "table" and #opts.Buttons > 0 then
 local row = new("Frame", {
 Size = UDim2.new(1, 0, 0, 22),
 BackgroundTransparency = 1,
 LayoutOrder = 3,
 Parent = text,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 Padding = UDim.new(0, 6),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 padding(4, 0, 0, 0),
 })
 for i, b in ipairs(opts.Buttons) do
 local primary = b.Primary or (i == 1 and #opts.Buttons == 1)
 local btn = new("TextButton", {
 Size = UDim2.fromOffset(0, 20),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = primary and color or Theme.Element,
 BackgroundTransparency = primary and 0.25 or 0,
 AutoButtonColor = false,
 FontFace = Fonts.Medium,
 Text = b.Name or "OK",
 TextColor3 = primary and WHITE or Theme.SubText,
 TextSize = 11,
 LayoutOrder = i,
 Parent = row,
 }, { corner(5), padding(0, 0, 10, 10) })
 if not primary then outline().Parent = btn end
 local rest = btn.BackgroundTransparency
 btn.MouseEnter:Connect(function()
 tween(btn, 0.12, primary and { BackgroundTransparency = 0 } or { BackgroundColor3 = Theme.ElementHover, TextColor3 = Theme.Text })
 end)
 btn.MouseLeave:Connect(function()
 tween(btn, 0.12, primary and { BackgroundTransparency = rest } or { BackgroundColor3 = Theme.Element, TextColor3 = Theme.SubText })
 end)
 btn.MouseButton1Click:Connect(function()
 playSound("Click")
 safeCall(b.Callback, handle)
 if not b.KeepOpen then task.spawn(close) end
 end)
 end
 end

 -- Close button, faint until the card is hovered.
 local x = new("ImageButton", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, 0, 0, 0),
 Size = UDim2.fromOffset(14, 14),
 BackgroundTransparency = 1,
 Image = resolveIcon("x") or "",
 ImageColor3 = Theme.SubText,
 ImageTransparency = 0.7,
 Parent = card,
 })
 x.MouseEnter:Connect(function() tween(x, 0.1, { ImageTransparency = 0, ImageColor3 = Theme.Text }) end)
 x.MouseLeave:Connect(function() tween(x, 0.1, { ImageTransparency = 0.3, ImageColor3 = Theme.SubText }) end)

 local timer = new("Frame", {
 AnchorPoint = Vector2.new(0, 1),
 Position = UDim2.new(0, 8, 1, -1),
 Size = UDim2.new(1, -16, 0, 2),
 BackgroundColor3 = color,
 BackgroundTransparency = 0.3,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = mover,
 }, { corner("full") })

 -- The wrapper's height follows the card. Not AutomaticSize: the shadow
 -- and timer are scale-sized and would feed back into it.
 local function fit() wrapper.Size = UDim2.new(1, 0, 0, card.AbsoluteSize.Y) end
 card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 fit()

 -- State -----------------------------------------------------------------
 local count, hovering = 1, false
 local total, remaining, persistent = 1, 1, false
 local function setDuration(d)
 if d == nil then
 d = kind.Persistent and 0 or (opts.Buttons and 8 or 4)
 end
 persistent = not d or d <= 0 or d == math.huge
 total = persistent and 1 or d
 remaining = total
 end
 setDuration(opts.Duration)

 local function renderTitle()
 local t = opts.Title or "Prism"
 if count > 1 then
 t ..= string.format(' ×%d ', Theme.Muted:ToHex(), count)
 end
 titleLabel.Text = t
 end
 renderTitle()

 local function applyKind()
 kind = NOTIFY_TYPES[opts.Type or "Info"] or NOTIFY_TYPES.Info
 color = kind.Color()
 iconImg.Image = resolveIcon(opts.Icon or kind.Icon) or ""
 iconImg.Rotation = 0
 for _, f in ipairs({ badge, wash, bar, timer }) do
 tween(f, 0.2, { BackgroundColor3 = color })
 end
 tween(iconImg, 0.2, { ImageColor3 = color })
 end

 local function showProgress(p)
 p = math.clamp(p, 0, 1)
 timer.Visible = true
 tween(timer, 0.2, { Size = UDim2.new(p, -16 * p, 0, 2) })
 end
 if type(opts.Progress) == "number" then showProgress(opts.Progress) end

 local key = notifyKey(opts)
 liveToasts[handle] = key

 handle._apply = function(c)
 if c.Title ~= nil then renderTitle() end
 if c.Content ~= nil then
 contentLabel.Text = c.Content
 contentLabel.Visible = c.Content ~= ""
 end
 if c.Type ~= nil or c.Icon ~= nil then
 applyKind()
 if c.Duration == nil then setDuration(nil) end
 end
 if c.Duration ~= nil then setDuration(c.Duration) end
 if c.Progress ~= nil then
 if type(c.Progress) == "number" then showProgress(c.Progress) end
 end
 -- Text changed: stop merging repeats of the old text into this one.
 liveToasts[handle] = nil
 end

 handle._bump = function()
 count += 1
 renderTitle()
 remaining = total
 playSound("Notify", 1.1)
 pop.Scale = 1.04
 tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
 end

 close = function()
 if closed then return end
 closed = true
 tickers[handle] = nil
 liveToasts[handle] = nil
 handle._apply, handle._bump, handle._close = nil, nil, nil
 safeCall(opts.OnClose, handle)
 tween(mover, 0.35, { Position = OFFSCREEN }, Enum.EasingStyle.Quint, Enum.EasingDirection.In).Completed:Wait()
 tween(wrapper, 0.25, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Wait()
 wrapper:Destroy()
 activeToasts -= 1
 local nextHandle = table.remove(queued, 1)
 updateMorePill()
 if nextHandle then showToast(nextHandle) end
 end
 handle._close = close

 -- Countdown (paused on hover), spinner, and the timer bar.
 local last = os.clock()
 tickers[handle] = function(t)
 local dt = t - last
 last = t
 if closed or not mover.Parent then
 tickers[handle] = nil
 return
 end
 if kind.Spin and not Prism.ReduceMotion then iconImg.Rotation = (t * 300) % 360 end
 if type(opts.Progress) == "number" then
 if persistent then return end
 elseif persistent then
 timer.Visible = false
 return
 else
 timer.Visible = true
 end
 if not hovering then remaining -= dt end
 if type(opts.Progress) ~= "number" then
 local f = math.clamp(remaining / total, 0, 1)
 timer.Size = UDim2.new(f, -16 * f, 0, 2)
 end
 if remaining <= 0 then task.spawn(close) end
 end

 tween(mover, 0.45, { Position = UDim2.fromOffset(0, 0) })
 tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

 x.MouseButton1Click:Connect(function() task.spawn(close) end)
 card.MouseButton1Click:Connect(function()
 safeCall(opts.Callback, handle)
 task.spawn(close)
 end)
 card.MouseEnter:Connect(function()
 hovering = true
 tween(card, 0.15, { BackgroundColor3 = Theme.Element })
 tween(x, 0.15, { ImageTransparency = 0.3 })
 end)
 card.MouseLeave:Connect(function()
 hovering = false
 tween(card, 0.15, { BackgroundColor3 = Theme.Surface })
 tween(x, 0.15, { ImageTransparency = 0.7 })
 end)
end

-- ============================================================================
-- INTRO
-- ============================================================================
local function playIntro(window, opts)
 local gui = window.Gui

 -- Everything in the intro is positioned in this gui's own space. Measure
 -- AbsolutePositions against a full-screen frame in the same gui rather
 -- than using them raw: with IgnoreGuiInset they don't share an origin with
 -- Position offsets, and the logo would land a topbar-height off the slot
 -- and then snap into place.
 local origin = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
 local function toGui(absolute) return absolute - origin.AbsolutePosition end

 local viewport = origin.AbsoluteSize
 if viewport.X == 0 then viewport = workspace.CurrentCamera.ViewportSize end

 local START_SCALE = 1.5
 local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.42)

 -- 1. Dim + blur ---------------------------------------------------------
 local overlay = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Color3.fromRGB(5, 4, 10),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ZIndex = 50,
 Parent = gui,
 })
 local blur
 pcall(function()
 blur = new("BlurEffect", { Name = "PrismBlur", Size = 0, Parent = Lighting })
 end)
 tween(overlay, 0.5, { BackgroundTransparency = 0.2 })
 if blur then tween(blur, 0.5, { Size = 20 }) end

 local fx = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 55, Parent = gui })

 local logo = buildLogo(gui, { Hidden = true, Scale = START_SCALE, ZIndex = 60 })
 logo.Holder.Position = UDim2.fromOffset(center.X, center.Y)

 -- Scatter the facets: each starts far out along its own direction, spun.
 for _, facet in ipairs(logo.Facets) do
 local out = facet.Home + facet.Outward * math.random(150, 230)
 facet.Frame.Position = UDim2.fromOffset(out.X, out.Y)
 facet.Frame.Rotation = facet.Rotation + math.random(-220, 220)
 end

 task.wait(0.2)

 -- 2. Crystal dust drifts in ---------------------------------------------
 for _ = 1, 22 do
 local angle = math.random() * math.pi * 2
 local from = center + Vector2.new(math.cos(angle), math.sin(angle)) * math.random(280, 560)
 local to = center + Vector2.new(math.random(-40, 40), math.random(-40, 40)) * START_SCALE
 local size = math.random(3, 7)
 local mote = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(from.X, from.Y),
 Size = UDim2.fromOffset(size, size),
 Rotation = 45,
 BackgroundColor3 = randomSpectrum(),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 Parent = fx,
 })
 task.delay(math.random() * 0.4, function()
 local travel = 0.7 + math.random() * 0.3
 tween(mote, 0.2, { BackgroundTransparency = 0.2 })
 tween(mote, travel, { Position = UDim2.fromOffset(to.X, to.Y) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
 task.wait(travel)
 tween(mote, 0.25, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
 task.wait(0.25)
 mote:Destroy()
 end)
 end

 task.wait(0.35)

 -- 3. Facets fly in and lock together ------------------------------------
 for i, facet in ipairs(logo.Facets) do
 task.delay((i - 1) * 0.07, function()
 tween(facet.Frame, 0.75, {
 Position = UDim2.fromOffset(facet.Home.X, facet.Home.Y),
 Rotation = facet.Rotation,
 BackgroundTransparency = 0,
 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 end)
 end
 task.wait(#logo.Facets * 0.07 + 0.6)

 -- Lock-in: the setting appears, the stone flashes white and settles to
 -- its colours, glint pops, ring goes out.
 tween(logo.Rim, 0.2, { BackgroundTransparency = 0 })
 for _, facet in ipairs(logo.Facets) do
 facet.Frame.BackgroundColor3 = WHITE
 tween(facet.Frame, 0.7, { BackgroundColor3 = facet.Color }, Enum.EasingStyle.Quad)
 end
 tween(logo.GlintScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

 local ring = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(center.X, center.Y),
 Size = UDim2.fromOffset(60, 60),
 Rotation = 45,
 BackgroundTransparency = 1,
 ZIndex = 58,
 Parent = fx,
 }, { corner(6) })
 local ringStroke = stroke(WHITE, 2, 0)
 ringStroke.Parent = ring
 tween(ring, 0.8, { Size = UDim2.fromOffset(380, 380) })
 tween(ringStroke, 0.8, { Transparency = 1 })
 tween(logo.Scale, 0.1, { Scale = START_SCALE * 1.06 }).Completed:Wait()
 tween(logo.Scale, 0.4, { Scale = START_SCALE }, Enum.EasingStyle.Back)
 task.delay(0.6, function() logo.Idle = true end)

 -- 4. Title + loading bar -------------------------------------------------
 local title = string.upper(opts.Title or "PRISM")
 local textBlock = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.fromOffset(center.X, center.Y + LOGO_SIZE * START_SCALE * 0.5 + 18),
 Size = UDim2.fromOffset(400, 120),
 BackgroundTransparency = 1,
 ZIndex = 60,
 Parent = gui,
 })
 local letterRow = new("Frame", {
 Size = UDim2.new(1, 0, 0, 46),
 BackgroundTransparency = 1,
 Parent = textBlock,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 HorizontalAlignment = Enum.HorizontalAlignment.Center,
 Padding = UDim.new(0, 8),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 local letters = {}
 for i = 1, #title do
 local slot = new("Frame", {
 Size = UDim2.fromOffset(30, 46),
 BackgroundTransparency = 1,
 LayoutOrder = i,
 Parent = letterRow,
 })
 local letter = new("TextLabel", {
 Position = UDim2.fromOffset(0, -22),
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = title:sub(i, i),
 TextColor3 = Theme.Text,
 TextSize = 40,
 TextTransparency = 1,
 Parent = slot,
 })
 table.insert(letters, letter)
 task.delay((i - 1) * 0.06, function()
 tween(letter, 0.5, { Position = UDim2.fromOffset(0, 0), TextTransparency = 0 }, Enum.EasingStyle.Back)
 end)
 end

 local tagline = new("TextLabel", {
 Position = UDim2.fromOffset(0, 50),
 Size = UDim2.new(1, 0, 0, 16),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = opts.Tagline or "",
 TextColor3 = Theme.SubText,
 TextSize = 13,
 TextTransparency = 1,
 Parent = textBlock,
 })
 tween(tagline, 0.6, { TextTransparency = 0 })

 local track = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.new(0.5, 0, 0, 82),
 Size = UDim2.fromOffset(220, 3),
 BackgroundColor3 = Theme.Stroke,
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 Parent = textBlock,
 }, { corner("full") })
 local fill = new("Frame", {
 Size = UDim2.fromScale(0, 1),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = track,
 }, { corner("full") })
 new("UIGradient", { Color = spectrumSequence(), Parent = fill })
 local status = new("TextLabel", {
 Position = UDim2.fromOffset(0, 92),
 Size = UDim2.new(1, 0, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "",
 TextColor3 = Theme.Muted,
 TextSize = 12,
 TextTransparency = 1,
 Parent = textBlock,
 })
 tween(track, 0.4, { BackgroundTransparency = 0 })
 tween(status, 0.4, { TextTransparency = 0 })

 local steps = opts.Steps or {
 "Refracting light",
 "Cutting facets",
 "Loading modules",
 "Ready",
 }
 if window._manualLoading then
 -- Live status: mirror whatever the script reports through
 -- Window:SetLoading until it finishes (or a 60 second safety net).
 local started = os.clock()
 local lastText, lastProgress
 while not window._loadingDone and os.clock() - started < 60 do
 local st = window._loadingState
 if st.Text ~= lastText then
 lastText = st.Text
 status.Text = st.Text
 end
 if st.Progress ~= lastProgress then
 lastProgress = st.Progress
 tween(fill, 0.3, { Size = UDim2.fromScale(st.Progress, 1) }, Enum.EasingStyle.Quad)
 end
 task.wait()
 end
 status.Text = window._loadingState.Text ~= "" and window._loadingState.Text or "Ready"
 tween(fill, 0.3, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad)
 task.wait(0.4)
 else
 for i, text in ipairs(steps) do
 status.Text = text
 tween(fill, 0.35, { Size = UDim2.fromScale(i / #steps, 1) }, Enum.EasingStyle.Quad)
 task.wait(0.4)
 end
 end
 task.wait(0.15)

 -- 5. Hand off to the window ---------------------------------------------
 for i, letter in ipairs(letters) do
 task.delay((i - 1) * 0.03, function()
 tween(letter, 0.3, { TextTransparency = 1, Position = UDim2.fromOffset(0, -10) })
 end)
 end
 tween(tagline, 0.3, { TextTransparency = 1 })
 tween(status, 0.3, { TextTransparency = 1 })
 tween(track, 0.3, { BackgroundTransparency = 1 })
 tween(fill, 0.3, { BackgroundTransparency = 1 })

 tween(overlay, 0.7, { BackgroundTransparency = 1 })
 if blur then tween(blur, 0.7, { Size = 0 }) end
 window:_reveal(0.55)

 -- Wind-up before launch
 tween(logo.Scale, 0.22, { Scale = START_SCALE * 1.1 }, Enum.EasingStyle.Quad).Completed:Wait()

 -- Flight: quadratic bezier that arcs up and over to the logo slot,
 -- spinning and shrinking. The target is re-read every frame so it tracks
 -- the window while it scales in. Scale ends at exactly what the docked
 -- logo will render at, so nothing jumps on the hand-off.
 local slot = window.LogoSlot
 local socket = window.Socket
 local dockScale = slot.Size.X.Offset / LOGO_SIZE
 local fromScale = logo.Scale.Scale
 local fromPos = center
 local duration = 1.0
 local started = os.clock()
 local lastSpark = 0
 local socketLit = false

 while true do
 local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
 local e = TweenService:GetValue(alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

 local target = toGui(slot.AbsolutePosition + slot.AbsoluteSize / 2)
 local control = Vector2.new(lerp(fromPos.X, target.X, 0.2), math.min(fromPos.Y, target.Y) - 160)
 local pos = fromPos * ((1 - e) ^ 2) + control * (2 * (1 - e) * e) + target * (e ^ 2)

 logo.Holder.Position = UDim2.fromOffset(pos.X, pos.Y)
 logo.Holder.Rotation = -360 * e
 logo.Scale.Scale = lerp(fromScale, dockScale * window.RootScale.Scale, e)

 -- The empty socket in the window lights up as the stone closes in.
 if socket and not socketLit and e > 0.55 then
 socketLit = true
 local socketStroke = socket:FindFirstChildOfClass("UIStroke")
 tween(socketStroke, 0.3, { Transparency = 0, Color = Theme.Accent })
 end

 if alpha > 0.04 and alpha < 0.96 and os.clock() - lastSpark > 0.016 then
 lastSpark = os.clock()
 local s = math.random(3, 6)
 local spark = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(pos.X + math.random(-6, 6), pos.Y + math.random(-6, 6)),
 Size = UDim2.fromOffset(s, s),
 Rotation = 45,
 BackgroundColor3 = randomSpectrum(),
 BorderSizePixel = 0,
 Parent = fx,
 })
 local drift = Vector2.new(math.random(-30, 30), math.random(-10, 40))
 tween(spark, 0.55, {
 Position = UDim2.fromOffset(pos.X + drift.X, pos.Y + drift.Y),
 Size = UDim2.fromOffset(0, 0),
 BackgroundTransparency = 1,
 }, Enum.EasingStyle.Quad)
 task.delay(0.6, function() spark:Destroy() end)
 end

 if alpha >= 1 then break end
 RunService.RenderStepped:Wait()
 end

 -- 6. Landing -------------------------------------------------------------
 local landAt = toGui(slot.AbsolutePosition + slot.AbsoluteSize / 2)

 -- Impact sparks, in screen space so they spill over the window edge.
 for i = 1, 10 do
 local angle = (i / 10) * math.pi * 2 + math.random() * 0.3
 local dir = Vector2.new(math.cos(angle), math.sin(angle))
 local to = landAt + dir * math.random(26, 46)
 local spark = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(landAt.X, landAt.Y),
 Size = UDim2.fromOffset(4, 4),
 Rotation = 45,
 BackgroundColor3 = randomSpectrum(),
 BorderSizePixel = 0,
 Parent = fx,
 })
 tween(spark, 0.45, { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 })
 end

 -- Dock. Same on-screen position and size as the last flight frame.
 logo.Holder.Rotation = 0
 logo.Holder.ZIndex = 5
 logo.Holder.Parent = slot
 logo.Holder.Position = UDim2.fromScale(0.5, 0.5)
 logo.Scale.Scale = dockScale
 window.Logo = logo

 if socket then
 local socketStroke = socket:FindFirstChildOfClass("UIStroke")
 tween(socket, 0.45, { Size = UDim2.fromOffset(socket.Size.X.Offset * 1.8, socket.Size.Y.Offset * 1.8) })
 tween(socketStroke, 0.45, { Transparency = 1 })
 task.delay(0.5, function() socket:Destroy() end)
 window.Socket = nil
 end

 tween(logo.Scale, 0.08, { Scale = dockScale * 1.18 }, Enum.EasingStyle.Quad).Completed:Connect(function()
 tween(logo.Scale, 0.45, { Scale = dockScale }, Enum.EasingStyle.Back)
 end)
 tween(window.RootScale, 0.08, { Scale = window.BaseScale * 1.01 }, Enum.EasingStyle.Quad).Completed:Connect(function()
 tween(window.RootScale, 0.35, { Scale = window.BaseScale }, Enum.EasingStyle.Back)
 end)
 window:_revealBrand()

 task.wait(0.7)
 overlay:Destroy()
 textBlock:Destroy()
 fx:Destroy()
 origin:Destroy()
 if blur then blur:Destroy() end
end

-- ============================================================================
-- EFFECTS
-- ============================================================================
-- Menu shine: one shared clock, so every active toggle, slider fill and
-- primary button catches the light at the same moment. Fills that shine
-- are CanvasGroups so the band is clipped to their rounded shape.
-- ============================================================================
local shines = {} -- [band] = true; strong, pruned below (see ACCENT)
local SHINE_PERIOD, SHINE_SWEEP = 3.4, 0.9
Prism.ShineEnabled = true

local function addShine(fill)
 -- The band moves outside the fill's bounds, so it sits behind a
 -- UIListLayout (see LAYOUT RULE below): otherwise an auto-sized fill
 -- (the PREMIUM badge) grew as the band swept and pushed its neighbours.
 local layer = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Parent = fill,
 }, { new("UIListLayout", {}) })
 local track = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Parent = layer,
 })
 local band = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.fromScale(-0.6, 0),
 Size = UDim2.new(0.7, 0, 1, 0),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = track,
 }, {
 new("UIGradient", {
 Transparency = NumberSequence.new({
 NumberSequenceKeypoint.new(0, 1),
 NumberSequenceKeypoint.new(0.5, 0.78),
 NumberSequenceKeypoint.new(1, 1),
 }),
 }),
 })
 shines[band] = true
 return band
end

tickers[shines] = function(t)
 local p = t % SHINE_PERIOD
 local x = p < SHINE_SWEEP and lerp(-0.6, 1.6, p / SHINE_SWEEP) or -0.6
 for band in pairs(shines) do
 if band.Parent then
 band.Visible = Prism.ShineEnabled and not Prism.ReduceMotion
 band.Position = UDim2.fromScale(x, 0)
 else
 shines[band] = nil
 end
 end
end

-- Accent-gradient fill with shine, clipped to its corners. The gradient
-- sits on an inner layer: on the CanvasGroup itself it would tint anything
-- placed inside (white text and icons came out purple).
local function accentFill(props, radius)
 local fill = new("CanvasGroup", props)
 fill.BackgroundTransparency = 1
 fill.BorderSizePixel = 0
 corner(radius or "full").Parent = fill
 local bg = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = fill,
 })
 accentGradient(bg)
 addShine(fill)
 return fill
end

-- Ink ripple from a click point. container: where the dot is parented
-- (positions are relative to it); bounds: the clipping frame it fills.
local function ripple(container, absolutePos, layoutScale, bounds)
 if Prism.ReduceMotion then return end
 bounds = bounds or container
 local rel = (absolutePos - container.AbsolutePosition) / layoutScale
 local size = math.max(bounds.AbsoluteSize.X, bounds.AbsoluteSize.Y) / layoutScale * 2.2
 local dot = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(rel.X, rel.Y),
 Size = UDim2.fromOffset(0, 0),
 BackgroundColor3 = WHITE,
 BackgroundTransparency = 0.92,
 BorderSizePixel = 0,
 ZIndex = 5,
 Parent = container,
 }, { corner("full") })
 tween(dot, 0.5, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
 task.delay(0.55, function() dot:Destroy() end)
end

-- Mouse position in the same space as AbsolutePosition inside an
-- IgnoreGuiInset gui (GetMouseLocation counts from the very top of the
-- screen; AbsolutePosition there sits a topbar-height higher).
local function mouseAbsolute()
 local inset = game:GetService("GuiService"):GetGuiInset()
 return UserInputService:GetMouseLocation() - Vector2.new(0, inset.Y)
end

-- ============================================================================
-- ELEMENTS
-- ============================================================================
-- Compact rows (26px) inside section cards:
--
-- row transparent until hovered
-- body name on the left, control on the right
-- extra (optional) full-width area under the body (dropdown options,
-- colour picker)
--
-- Description shows as a tooltip on hover, keeping rows one line tall.
--
-- LAYOUT RULE: an AutomaticSize frame without a UIListLayout grows to fit
-- every descendant, clipped or not. Anything that animates bigger than its
-- row (ripples) lives behind a UIListLayout so it can't stretch the row.
-- ============================================================================
local Section = {}
Section.__index = Section

local ROW_H = 26
local CONTROL_H = 20

local function registerFlag(flag, el)
 if flag and flag ~= "" then Prism.Flags[flag] = el end
end

function Section:_nextOrder()
 self._order += 1
 return self._order
end

-- labelWidth: UDim2 whose X is the label column width.
local function baseRow(section, opts, labelWidth)
 local row = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Element,
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ClipsDescendants = true,
 LayoutOrder = section:_nextOrder(),
 Parent = section.Container,
 }, {
 corner(4),
 new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
 })

 local body = new("Frame", {
 Size = UDim2.new(1, 0, 0, ROW_H),
 BackgroundTransparency = 1,
 LayoutOrder = 1,
 Parent = row,
 })

 local title = new("TextLabel", {
 Position = UDim2.fromOffset(8, 0),
 Size = UDim2.new(labelWidth.X.Scale, labelWidth.X.Offset - 8, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = opts.Name or "",
 TextColor3 = opts.Risky and Theme.Warning or Theme.Text,
 TextSize = 12,
 RichText = true,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = body,
 })

 local entry = section.Window:_indexElement(opts.Name, section, row)
 return row, body, title, entry
end

-- Hover highlight + tooltip for any row-like frame.
local function rowHover(section, row, trigger, description)
 trigger.MouseEnter:Connect(function()
 tween(row, 0.12, { BackgroundTransparency = 0 })
 if description and description ~= "" then section.Window:_showTooltip(description) end
 end)
 trigger.MouseLeave:Connect(function()
 tween(row, 0.18, { BackgroundTransparency = 1 })
 section.Window:_hideTooltip()
 end)
end

-- Transparent button over the body for hover/press/click, with a ripple.
local function rowHitbox(section, row, body, description)
 local hit = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 AutoButtonColor = false,
 ZIndex = 2,
 Parent = body,
 })
 rowHover(section, row, hit, description)

 -- Ripples get their own clipped layer with a UIListLayout (see LAYOUT
 -- RULE above); the dots hang off a zero-size anchor inside it.
 local fx = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = body,
 }, { new("UIListLayout", {}) })
 local anchor = new("Frame", { Size = UDim2.new(), BackgroundTransparency = 1, Parent = fx })
 hit.MouseButton1Down:Connect(function()
 ripple(anchor, mouseAbsolute(), section.Window:_layoutScale(), fx)
 end)
 return hit
end

-- Right-aligned, vertically centred control slot.
local function controlProps(size, offset)
 return {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, offset or -8, 0.5, 0),
 Size = size,
 ZIndex = 3,
 }
end

-- Shared element methods. Lock greys the row out and blocks input.
-- overlayParent: a frame without a list layout to float the lock over
-- (the row body), so the overlay isn't laid out as a list item.
local function element(row, title, overlayParent)
 local e = { Frame = row }
 local lock
 function e:SetName(text) title.Text = text end
 function e:GetName() return title.Text end
 function e:SetVisible(visible) row.Visible = visible end
 function e:SetLocked(locked, reason)
 self.Locked = locked
 if locked and not lock then
 lock = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Theme.Surface,
 BackgroundTransparency = 0,
 AutoButtonColor = false,
 FontFace = Fonts.Medium,
 Text = "",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Right,
 ZIndex = 8,
 Parent = overlayParent or row,
 }, {
 corner(4),
 padding(0, 0, 8, 26),
 -- Light over the name, solid over the control on the right.
 new("UIGradient", {
 Transparency = NumberSequence.new({
 NumberSequenceKeypoint.new(0, 0.55),
 NumberSequenceKeypoint.new(0.5, 0.35),
 NumberSequenceKeypoint.new(0.62, 0),
 NumberSequenceKeypoint.new(1, 0),
 }),
 }),
 })
 icon("lock", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, 18, 0.5, 0),
 ZIndex = 9,
 Parent = lock,
 })
 end
 if lock then
 lock.Visible = locked
 lock.Text = reason or "Locked"
 end
 end
 return e
end

local function chip(props)
 local c = new("TextLabel", props)
 c.BackgroundColor3 = Theme.Input
 c.BorderSizePixel = 0
 c.FontFace = Fonts.Medium
 c.TextColor3 = Theme.SubText
 c.TextSize = 10
 corner(3).Parent = c
 outline().Parent = c
 return c
end

-- Colour picker panel, shared by ColorPicker and Toggle{ Color }. Lives in
-- the row's extra area; returns an object with :Set, :SetOpen, .Value.
local function buildPicker(section, row, swatch, initial, onChange)
 local PICK_H = 96
 local extra = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 LayoutOrder = 2,
 Parent = row,
 })

 local sv = new("Frame", {
 Position = UDim2.fromOffset(8, 2),
 Size = UDim2.new(1, -42, 0, PICK_H),
 BorderSizePixel = 0,
 Parent = extra,
 }, { corner(4) })
 new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = sv,
 }, { corner(4), new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
 new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Color3.new(0, 0, 0),
 BorderSizePixel = 0,
 Parent = sv,
 }, { corner(4), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
 local svCursor = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Size = UDim2.fromOffset(10, 10),
 BackgroundTransparency = 1,
 ZIndex = 2,
 Parent = sv,
 }, { corner("full"), stroke(WHITE, 2, 0) })

 local hueKeys = {}
 for i = 0, 6 do
 table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
 end
 local hue = new("Frame", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -8, 0, 2),
 Size = UDim2.fromOffset(18, PICK_H),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = extra,
 }, { corner(4), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys) }) })
 local hueCursor = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0),
 Size = UDim2.new(1, 4, 0, 4),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = hue,
 }, { corner(2), stroke(Color3.new(0, 0, 0), 1, 0.6) })

 local hexBox = new("TextBox", {
 Position = UDim2.fromOffset(8, PICK_H + 8),
 Size = UDim2.fromOffset(80, CONTROL_H),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 ClearTextOnFocus = false,
 FontFace = Fonts.Medium,
 TextColor3 = Theme.Text,
 TextSize = 11,
 Parent = extra,
 }, { corner(4), outline() })
 local rgbLabel = new("TextLabel", {
 Position = UDim2.fromOffset(96, PICK_H + 8),
 Size = UDim2.new(1, -104, 0, CONTROL_H),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = extra,
 })
 local OPEN_H = PICK_H + CONTROL_H + 16

 local picker = { Open = false }
 local h, s, v = 0, 0, 1

 local function render(fire)
 local color = Color3.fromHSV(h, s, v)
 picker.Value = color
 sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
 svCursor.Position = UDim2.fromScale(s, 1 - v)
 hueCursor.Position = UDim2.fromScale(0.5, h)
 swatch.BackgroundColor3 = color
 hexBox.Text = "#" .. color:ToHex():upper()
 rgbLabel.Text = string.format("%d, %d, %d",
 math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
 if fire then onChange(color) end
 end

 function picker:Set(color, silent)
 if typeof(color) == "table" then color = Color3.new(color[1], color[2], color[3]) end
 h, s, v = color:ToHSV()
 render(not silent)
 end

 function picker:SetOpen(open)
 self.Open = open
 tween(extra, 0.25, { Size = UDim2.new(1, 0, 0, open and OPEN_H or 0) })
 end

 local dragSV, dragHue = false, false
 local function updateFrom(pos)
 if dragSV then
 s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
 v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
 render(true)
 elseif dragHue then
 h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
 render(true)
 end
 end
 local function dragArea(target, setFlag)
 local hit = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 3,
 Parent = target,
 })
 hit.InputBegan:Connect(function(input)
 if isMouseOrTouch(input) then
 setFlag(true)
 updateFrom(input.Position)
 end
 end)
 end
 dragArea(sv, function(b) dragSV = b end)
 dragArea(hue, function(b) dragHue = b end)
 table.insert(section.Window._conns, UserInputService.InputChanged:Connect(function(input)
 if (dragSV or dragHue) and isMove(input) then updateFrom(input.Position) end
 end))
 table.insert(section.Window._conns, UserInputService.InputEnded:Connect(function(input)
 if isMouseOrTouch(input) then dragSV, dragHue = false, false end
 end))

 hexBox.FocusLost:Connect(function()
 local ok, color = pcall(Color3.fromHex, (hexBox.Text:gsub("#", "")))
 if ok and color then picker:Set(color) else render(false) end
 end)

 picker:Set(initial or Theme.Accent, true)
 return picker
end

local function swatchProps(offset)
 local props = controlProps(UDim2.fromOffset(24, 14), offset)
 return props
end

-- Button --------------------------------------------------------------------
-- Button{ Name, Description, Icon, Style = "Primary", Confirm, ConfirmText,
-- Hold, HoldText, Callback }
-- Hold = true (or seconds) makes it hold-to-confirm: a fill sweeps across
-- while the button is held and the callback runs when it completes.

-- Builds one button face inside parent. Shared by Button and ButtonRow.
local function buildButton(section, parent, opts, size)
 local primary = opts.Style == "Primary"
 local face
 if primary then
 face = accentFill({ Size = size, ZIndex = 2, Parent = parent }, 4)
 local glow = softGlow(parent, face, 6, 0.8)
 bindAccent(glow, "ImageColor3")
 face.MouseEnter:Connect(function() tween(glow, 0.15, { ImageTransparency = 0.55 }) end)
 face.MouseLeave:Connect(function() tween(glow, 0.2, { ImageTransparency = 0.8 }) end)
 else
 face = new("Frame", {
 Size = size,
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = parent,
 }, {
 corner(4),
 -- Lit from above: slightly brighter at the top.
 new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 208)) }),
 })
 end
 local faceStroke = outline(primary and 1 or Theme.OutlineTransparency)
 faceStroke.Parent = face

 local holdTime = opts.Hold and (typeof(opts.Hold) == "number" and opts.Hold or 1.2)
 local holdFill
 if holdTime then
 holdFill = new("Frame", {
 Size = UDim2.fromScale(0, 1),
 BackgroundColor3 = primary and WHITE or Theme.Accent,
 BackgroundTransparency = primary and 0.7 or 0.6,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = face,
 }, { corner(4) })
 if not primary then bindAccent(holdFill, "BackgroundColor3") end
 end

 local content = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 ZIndex = 2,
 Parent = face,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 6),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 local glyph
 if resolveIcon(opts.Icon) then
 glyph = icon(opts.Icon, 12, primary and WHITE or Theme.SubText, { LayoutOrder = 1, Parent = content })
 end
 local label = new("TextLabel", {
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = primary and Fonts.SemiBold or Fonts.Medium,
 Text = opts.Name or "Button",
 TextColor3 = primary and WHITE or Theme.Text,
 TextSize = 12,
 LayoutOrder = 2,
 Parent = content,
 })

 local hit = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 3,
 Parent = face,
 })
 hit.MouseEnter:Connect(function()
 if primary then
 tween(face, 0.12, { GroupTransparency = 0.1 })
 else
 tween(face, 0.12, { BackgroundColor3 = Theme.ElementHover })
 tween(faceStroke, 0.12, { Color = Theme.Accent, Transparency = 0.45 })
 if glyph then tween(glyph, 0.12, { ImageColor3 = Theme.Accent }) end
 end
 if opts.Description then section.Window:_showTooltip(opts.Description) end
 end)
 hit.MouseLeave:Connect(function()
 if primary then
 tween(face, 0.12, { GroupTransparency = 0 })
 else
 tween(face, 0.15, { BackgroundColor3 = Theme.Element })
 tween(faceStroke, 0.15, { Color = Theme.Outline, Transparency = Theme.OutlineTransparency })
 if glyph then tween(glyph, 0.15, { ImageColor3 = Theme.SubText }) end
 end
 section.Window:_hideTooltip()
 end)
 -- Press: a quick dip in size.
 local pressScale = new("UIScale", { Parent = face })
 hit.MouseButton1Down:Connect(function()
 if not Prism.ReduceMotion then tween(pressScale, 0.08, { Scale = 0.97 }) end
 end)
 hit.MouseButton1Up:Connect(function() tween(pressScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back) end)
 hit.MouseLeave:Connect(function() tween(pressScale, 0.2, { Scale = 1 }) end)

 if holdTime then
 local holding
 local function cancel()
 if not holding then return end
 holding = nil
 tween(holdFill, 0.2, { Size = UDim2.fromScale(0, 1) })
 label.Text = opts.Name or ""
 end
 hit.MouseButton1Down:Connect(function()
 local token = {}
 holding = token
 label.Text = opts.HoldText or "Hold to confirm"
 holdFill.Size = UDim2.fromScale(0, 1)
 tween(holdFill, holdTime, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear).Completed:Connect(function(state)
 if state ~= Enum.PlaybackState.Completed or holding ~= token then return end
 holding = nil
 playSound("Toggle", 1.2)
 label.Text = opts.Name or ""
 tween(holdFill, 0.3, { BackgroundTransparency = 1 }).Completed:Connect(function()
 holdFill.Size = UDim2.fromScale(0, 1)
 holdFill.BackgroundTransparency = primary and 0.7 or 0.6
 end)
 safeCall(opts.Callback)
 end)
 end)
 hit.MouseButton1Up:Connect(cancel)
 hit.MouseLeave:Connect(cancel)
 end

 local armed = false
 hit.MouseButton1Click:Connect(function()
 if holdTime then return end
 playSound("Click")
 if opts.Confirm and not armed then
 armed = true
 label.Text = opts.ConfirmText or "Click again to confirm"
 label.TextColor3 = Theme.Warning
 task.delay(2.5, function()
 if armed then
 armed = false
 label.Text = opts.Name or ""
 label.TextColor3 = primary and WHITE or Theme.Text
 end
 end)
 return
 end
 if armed then
 armed = false
 label.Text = opts.Name or ""
 label.TextColor3 = primary and WHITE or Theme.Text
 end
 safeCall(opts.Callback)
 end)

 -- Palette action: Run. Confirm and Hold buttons stay click-only (they
 -- guard destructive actions).
 local entry = section.Window:_indexElement(opts.Name, section, parent)
 if entry and not opts.Confirm and not opts.Hold then
 entry.Kind = "Button"
 entry.Run = opts.Callback
 end
 return face, label
end

function Section:Button(opts)
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, ROW_H + 2),
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 }, { padding(2, 2, 2, 2) })
 local _, label = buildButton(self, holder, opts, UDim2.fromScale(1, 1))
 local e = element(holder, label)
 self.Window:_depends(e, opts)
 return e
end

-- ButtonRow{ { Name, Icon, Style, Confirm, Callback }, ... }
-- Several buttons side by side, sharing the width equally.
function Section:ButtonRow(list)
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, ROW_H + 2),
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 }, {
 padding(2, 2, 2, 2),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 Padding = UDim.new(0, 4),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 local n = #list
 local out = {}
 for i, opts in ipairs(list) do
 local cell = new("Frame", {
 Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0),
 BackgroundTransparency = 1,
 LayoutOrder = i,
 Parent = holder,
 })
 local _, label = buildButton(self, cell, opts, UDim2.fromScale(1, 1))
 out[i] = element(cell, label)
 end
 return out
end

-- Toggle --------------------------------------------------------------------
-- Toggle{ Name, Description, Default, Flag, Risky, Style = "Checkbox",
-- Keybind = Enum.KeyCode.X, Mode = "Toggle" | "Hold",
-- Color = Color3, ColorFlag, ColorCallback, Callback }
-- Right-click the row to bind a key (Escape or Backspace clears it).
-- Color adds an inline swatch that opens a colour picker (ESP style).
function Section:Toggle(opts)
 local window = self.Window
 local section = self
 local row, body, title, entry = baseRow(self, opts, UDim2.new(1, -110, 0, 0))
 local checkbox = opts.Style == "Checkbox"

 local track, fill, knob, check
 if checkbox then
 track = new("Frame", controlProps(UDim2.fromOffset(14, 14)))
 track.BackgroundColor3 = Theme.Input
 track.BorderSizePixel = 0
 track.Parent = body
 corner(3).Parent = track
 outline(0.85).Parent = track
 fill = accentFill({ Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = track }, 3)
 check = icon("check", 10, WHITE, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = fill,
 })
 else
 track = new("Frame", controlProps(UDim2.fromOffset(28, 16)))
 track.BackgroundColor3 = Theme.Input
 track.BorderSizePixel = 0
 track.Parent = body
 corner("full").Parent = track
 outline(0.85).Parent = track
 fill = accentFill({ Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = track })
 knob = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 3, 0.5, 0),
 Size = UDim2.fromOffset(10, 10),
 BackgroundColor3 = Theme.Muted,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = track,
 }, { corner("full") })
 end
 local nextX = -8 - (checkbox and 14 or 28) - 6
 local glow = softGlow(body, track, 6, 1)
 bindAccent(glow, "ImageColor3")

 -- Optional inline colour swatch
 local swatch, picker
 if opts.Color then
 swatch = new("TextButton", swatchProps(nextX))
 swatch.AutoButtonColor = false
 swatch.Text = ""
 swatch.BorderSizePixel = 0
 swatch.ZIndex = 4
 swatch.Parent = body
 corner(3).Parent = swatch
 outline(0.8).Parent = swatch
 nextX -= 24 + 6
 end

 -- Bound key chip
 local keyChip = chip(controlProps(UDim2.fromOffset(0, 16), nextX))
 keyChip.AutomaticSize = Enum.AutomaticSize.X
 keyChip.Visible = false
 keyChip.Parent = body
 padding(0, 0, 5, 5).Parent = keyChip

 local toggle = element(row, title, body)
 toggle.Value = false
 toggle.Key = nil
 toggle.Mode = opts.Mode or "Toggle"
 local listening = false

 -- Label takes whatever the controls on the right leave free.
 local function fitLabel()
 local reserve = -nextX + 6
 if keyChip.Visible then
 reserve += keyChip.AbsoluteSize.X / window:_layoutScale() + 6
 end
 title.Size = UDim2.new(1, -(reserve + 8), 1, 0)
 end

 local function renderKey()
 keyChip.Visible = listening or toggle.Key ~= nil
 keyChip.Text = listening and "..." or (toggle.Key and toggle.Key.Name or "")
 keyChip.TextColor3 = listening and Theme.Accent or Theme.SubText
 task.defer(fitLabel)
 end

 function toggle:Set(value, silent)
 local was = self.Value
 self.Value = value and true or false
 local on = self.Value
 tween(fill, 0.18, { GroupTransparency = on and 0 or 1 })
 tween(glow, 0.25, { ImageTransparency = on and 0.6 or 1 })
 if knob then
 tween(knob, 0.2, { BackgroundColor3 = on and WHITE or Theme.Muted })
 local target = UDim2.new(0, on and 15 or 3, 0.5, 0)
 if silent or was == on or Prism.ReduceMotion then
 knob.Position = target
 knob.Size = UDim2.fromOffset(10, 10)
 else
 -- Squash: stretch toward the destination, then settle there.
 tween(knob, 0.09, {
 Size = UDim2.fromOffset(16, 10),
 Position = UDim2.new(0, on and 3 or 9, 0.5, 0),
 }, Enum.EasingStyle.Quad).Completed:Connect(function(state)
 if state ~= Enum.PlaybackState.Completed or toggle.Value ~= on then return end
 tween(knob, 0.24, { Size = UDim2.fromOffset(10, 10), Position = target }, Enum.EasingStyle.Back)
 end)
 end
 end
 if not silent then playSound("Toggle", on and 1.15 or 0.9) end
 if check then
 check.Size = UDim2.fromOffset(on and 4 or 10, on and 4 or 10)
 tween(check, 0.22, { Size = UDim2.fromOffset(10, 10) }, Enum.EasingStyle.Back)
 end
 window:_refreshKeybinds()
 window:_refreshModules()
 if not silent then safeCall(opts.Callback, on) end
 end
 function toggle:Get() return self.Value end
 function toggle:SetKey(key, mode)
 if typeof(key) == "string" then key = Enum.KeyCode[key] end
 self.Key = key
 if mode then self.Mode = mode end
 renderKey()
 window:_refreshKeybinds()
 end

 local hit = rowHitbox(self, row, body, opts.Description)
 hit.MouseButton1Click:Connect(function()
 if toggle.Locked then return end
 toggle:Set(not toggle.Value)
 end)
 -- Only one element listens for a key at a time: right-clicking another
 -- toggle (or clicking a keybind) moves the listening state over to it.
 function toggle:_stopListening()
 listening = false
 renderKey()
 end
 hit.MouseButton2Click:Connect(function()
 window:_claimListener(toggle)
 listening = true
 renderKey()
 end)

 if swatch then
 picker = buildPicker(self, row, swatch, opts.Color, function(color)
 toggle.Color = color
 safeCall(opts.ColorCallback, color)
 end)
 toggle.Color = picker.Value
 swatch.MouseButton1Click:Connect(function() picker:SetOpen(not picker.Open) end)
 local colorEl = {
 Value = picker.Value,
 Set = function(selfEl, c, silent)
 picker:Set(c, silent)
 selfEl.Value = picker.Value
 toggle.Color = picker.Value
 end,
 }
 toggle.ColorPicker = colorEl
 registerFlag(opts.ColorFlag, colorEl)
 end

 table.insert(window._conns, UserInputService.InputBegan:Connect(function(input, processed)
 if listening then
 if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
 listening = false
 window:_releaseListener(toggle)
 local clear = input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace
 local previous = toggle.Key
 toggle:SetKey(not clear and input.KeyCode or nil)
 if not clear then
 window:_warnKeyConflict(toggle, input.KeyCode, function() toggle:SetKey(previous) end)
 end
 return
 end
 if processed or not toggle.Key or input.KeyCode ~= toggle.Key or toggle.Locked then return end
 if toggle.Mode == "Hold" then toggle:Set(true) else toggle:Set(not toggle.Value) end
 end))
 table.insert(window._conns, UserInputService.InputEnded:Connect(function(input)
 if toggle.Mode == "Hold" and toggle.Key and input.KeyCode == toggle.Key then toggle:Set(false) end
 end))

 -- Inline sub-settings: toggle:AddSettings() returns a Section that lives
 -- in a panel under this row, opened with a gear on the row.
 function toggle:AddSettings()
 if self._settings then return self._settings end
 local gear = new("TextButton", controlProps(UDim2.fromOffset(18, 18), nextX))
 gear.BackgroundColor3 = Theme.ElementHover
 gear.BackgroundTransparency = 1
 gear.AutoButtonColor = false
 gear.Text = ""
 gear.ZIndex = 4
 gear.Parent = body
 corner(4).Parent = gear
 local gearIcon = icon("settings", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 ZIndex = 4,
 Parent = gear,
 })
 nextX -= 18 + 4
 keyChip.Position = UDim2.new(1, nextX, 0.5, 0)
 fitLabel()

 local panel = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 LayoutOrder = 3,
 Parent = row,
 }, { padding(0, 6, 0, 0) })
 local inner = new("Frame", {
 Position = UDim2.fromOffset(8, 0),
 Size = UDim2.new(1, -16, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Input,
 BackgroundTransparency = 0.2,
 BorderSizePixel = 0,
 Parent = panel,
 }, { corner(5), outline(), padding(3, 3, 3, 3) })
 local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })

 local sub = setmetatable({
 Container = inner,
 Window = window,
 Tab = section.Tab,
 Name = (section.Name or "") .. " › " .. (opts.Name or ""),
 Collapsed = false,
 SetCollapsed = function() end,
 _order = 0,
 }, Section)

 local open = false
 function sub:SetOpen(on)
 open = on
 tween(gearIcon, 0.25, { Rotation = on and 90 or 0, ImageColor3 = on and Theme.Accent or Theme.Muted })
 local full = layout.AbsoluteContentSize.Y / window:_layoutScale() + 12
 panel.AutomaticSize = Enum.AutomaticSize.None
 if on then
 panel.Size = UDim2.new(1, 0, 0, 0)
 tween(panel, 0.25, { Size = UDim2.new(1, 0, 0, full) }).Completed:Connect(function()
 if open then panel.AutomaticSize = Enum.AutomaticSize.Y end
 end)
 else
 panel.Size = UDim2.new(1, 0, 0, full)
 tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
 end
 end
 gear.MouseEnter:Connect(function()
 tween(gear, 0.12, { BackgroundTransparency = 0 })
 window:_showTooltip("Settings")
 end)
 gear.MouseLeave:Connect(function()
 tween(gear, 0.12, { BackgroundTransparency = 1 })
 window:_hideTooltip()
 end)
 gear.MouseButton1Click:Connect(function()
 playSound("Click", 1.1)
 sub:SetOpen(not open)
 end)

 self._settings = sub
 return sub
 end

 toggle.Name = opts.Name
 toggle.HideFromList = opts.HideFromList
 if entry then
 entry.Kind = "Toggle"
 entry.Element = toggle
 end
 fitLabel()
 table.insert(window._bindables, toggle)
 if opts.Keybind then toggle:SetKey(opts.Keybind) end
 toggle:Set(opts.Default or false, true)
 if opts.Default then safeCall(opts.Callback, true) end
 registerFlag(opts.Flag, toggle)
 self.Window:_depends(toggle, opts)
 return toggle
end

-- Slider --------------------------------------------------------------------
-- Slider{ Name, Description, Min, Max, Default, Increment, Suffix, Flag, Callback }
-- Two lines: name and value on top, a full-width track underneath.
-- Click the value to type one.
function Section:Slider(opts)
 local min, max = opts.Min or 0, opts.Max or 100
 local increment = opts.Increment or 1
 local suffix = opts.Suffix or ""

 local row, body, title = baseRow(self, opts, UDim2.new(1, -60, 0, 0))
 body.Size = UDim2.new(1, 0, 0, 20)
 title.Position = UDim2.fromOffset(8, 2)

 -- Value: plain text that turns into an input when clicked.
 local valueBox = new("TextBox", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -8, 0, 2),
 Size = UDim2.fromOffset(52, 18),
 BackgroundColor3 = Theme.Input,
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ClearTextOnFocus = false,
 FontFace = Fonts.Medium,
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Right,
 ZIndex = 3,
 Parent = body,
 }, { corner(3) })

 local extra = new("Frame", {
 Size = UDim2.new(1, 0, 0, 14),
 BackgroundTransparency = 1,
 LayoutOrder = 2,
 Parent = row,
 })
 local track = new("Frame", {
 Position = UDim2.new(0, 8, 0, 3),
 Size = UDim2.new(1, -16, 0, 4),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = extra,
 }, { corner("full"), outline(0.9) })
 local fill = accentFill({ Size = UDim2.fromScale(0, 1), Parent = track })
 local knob = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0, 0.5),
 Size = UDim2.fromOffset(10, 10),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = track,
 }, { corner("full") })
 local halo = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(18, 18),
 BackgroundTransparency = 0.82,
 BorderSizePixel = 0,
 ZIndex = 1,
 Parent = knob,
 }, { corner("full") })
 bindAccent(halo, "BackgroundColor3")

 local slider = element(row, title, body)

 function slider:Set(value, silent)
 value = math.clamp(tonumber(value) or min, min, max)
 value = math.floor(value / increment + 0.5) * increment
 value = math.clamp(tonumber(formatNumber(value)), min, max)
 local changed = value ~= self.Value
 self.Value = value
 local rel = (max == min) and 0 or (value - min) / (max - min)
 tween(fill, 0.1, { Size = UDim2.fromScale(rel, 1) }, Enum.EasingStyle.Quad)
 tween(knob, 0.1, { Position = UDim2.fromScale(rel, 0.5) }, Enum.EasingStyle.Quad)
 valueBox.Text = formatNumber(value) .. suffix
 if changed and not silent then safeCall(opts.Callback, value) end
 end
 function slider:Get() return self.Value end
 -- Change the range at runtime; the value is clamped into it.
 function slider:SetRange(newMin, newMax)
 min, max = newMin or min, newMax or max
 self:Set(self.Value, true)
 end
 function slider:SetMin(v) self:SetRange(v, nil) end
 function slider:SetMax(v) self:SetRange(nil, v) end

 local dragging = false
 local function update(x)
 local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
 slider:Set(lerp(min, max, rel))
 end

 local hit = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 2,
 Parent = extra,
 })
 rowHover(self, row, hit, opts.Description)
 hit.InputBegan:Connect(function(input)
 if isMouseOrTouch(input) and not slider.Locked then
 dragging = true
 tween(knob, 0.12, { Size = UDim2.fromOffset(13, 13) })
 update(input.Position.X)
 end
 end)
 table.insert(self.Window._conns, UserInputService.InputChanged:Connect(function(input)
 if dragging and isMove(input) then update(input.Position.X) end
 end))
 table.insert(self.Window._conns, UserInputService.InputEnded:Connect(function(input)
 if dragging and isMouseOrTouch(input) then
 dragging = false
 tween(knob, 0.12, { Size = UDim2.fromOffset(10, 10) })
 end
 end))

 valueBox.Focused:Connect(function()
 tween(valueBox, 0.12, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
 valueBox.Text = formatNumber(slider.Value)
 end)
 valueBox.FocusLost:Connect(function()
 tween(valueBox, 0.12, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
 slider:Set(tonumber(valueBox.Text) or slider.Value)
 valueBox.Text = formatNumber(slider.Value) .. suffix
 end)

 slider:Set(opts.Default or min, true)
 if opts.Default then safeCall(opts.Callback, slider.Value) end
 registerFlag(opts.Flag, slider)
 self.Window:_depends(slider, opts)
 return slider
end

-- Dropdown ------------------------------------------------------------------
-- Dropdown{ Name, Description, Options, Default, Multi, Placeholder, Flag, Callback }
-- Lists longer than 6 get a search box.
function Section:Dropdown(opts)
 local multi = opts.Multi or false
 local OPTION_H, MAX_VISIBLE = 22, 6

 local row, body, title = baseRow(self, opts, UDim2.new(0.45, 0, 0, 0))

 local select = new("Frame", controlProps(UDim2.new(0.55, -8, 0, CONTROL_H)))
 select.BackgroundColor3 = Theme.Input
 select.BorderSizePixel = 0
 select.Parent = body
 corner(4).Parent = select
 local selectStroke = outline()
 selectStroke.Parent = select

 local valueLabel = new("TextLabel", {
 Position = UDim2.fromOffset(7, 0),
 Size = UDim2.new(1, -26, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 TextColor3 = Theme.Text,
 TextSize = 11,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = select,
 })
 local chevron = icon("chevron-down", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -5, 0.5, 0),
 Parent = select,
 })

 local extra = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 LayoutOrder = 2,
 Parent = row,
 })
 local panel = new("Frame", {
 Position = UDim2.fromOffset(6, 0),
 Size = UDim2.new(1, -12, 1, -6),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = extra,
 }, { corner(4), outline() })

 local searchBox = new("TextBox", {
 Position = UDim2.fromOffset(4, 4),
 Size = UDim2.new(1, -8, 0, CONTROL_H),
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 ClearTextOnFocus = false,
 FontFace = Fonts.Regular,
 PlaceholderText = "Search...",
 PlaceholderColor3 = Theme.Muted,
 Text = "",
 TextColor3 = Theme.Text,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Visible = false,
 Parent = panel,
 }, { corner(3), padding(0, 0, 7, 7) })

 local list = new("ScrollingFrame", {
 Position = UDim2.fromOffset(3, 3),
 Size = UDim2.new(1, -6, 1, -6),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ScrollBarThickness = 2,
 ScrollBarImageColor3 = Theme.Muted,
 ScrollingDirection = Enum.ScrollingDirection.Y,
 CanvasSize = UDim2.new(),
 AutomaticCanvasSize = Enum.AutomaticSize.Y,
 Parent = panel,
 }, { new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }) })

 local dropdown = element(row, title, body)
 dropdown.Value = multi and {} or nil
 dropdown.Options = {}
 dropdown.Open = false
 local buttons = {}

 local function isSelected(option)
 if multi then return table.find(dropdown.Value, option) ~= nil end
 return dropdown.Value == option
 end

 local function hasSearch() return #dropdown.Options > MAX_VISIBLE end

 local function render()
 local text
 if multi then
 text = #dropdown.Value > 0 and table.concat(dropdown.Value, ", ") or nil
 else
 text = dropdown.Value ~= nil and tostring(dropdown.Value) or nil
 end
 valueLabel.Text = text or (opts.Placeholder or "Select...")
 valueLabel.TextColor3 = text and Theme.Text or Theme.Muted
 for option, b in pairs(buttons) do
 local on = isSelected(option)
 tween(b.Button, 0.12, { BackgroundTransparency = on and 0 or 1 })
 tween(b.Label, 0.12, { TextColor3 = on and Theme.Text or Theme.SubText })
 tween(b.Check, 0.12, { ImageTransparency = on and 0 or 1 })
 end
 end

 local function panelHeight()
 local visible = 0
 for _, b in pairs(buttons) do
 if b.Button.Visible then visible += 1 end
 end
 local h = math.min(math.max(visible, 1), MAX_VISIBLE) * (OPTION_H + 1) + 6
 if hasSearch() then h += CONTROL_H + 4 end
 return h + 6
 end

 local function layoutPanel()
 local top = hasSearch() and (CONTROL_H + 7) or 3
 searchBox.Visible = hasSearch()
 list.Position = UDim2.fromOffset(3, top)
 list.Size = UDim2.new(1, -6, 1, -(top + 3))
 end

 function dropdown:SetOpen(open)
 self.Open = open
 tween(chevron, 0.2, { Rotation = open and 180 or 0 })
 tween(selectStroke, 0.15, {
 Color = open and Theme.Accent or Theme.Outline,
 Transparency = open and 0.2 or Theme.OutlineTransparency,
 })
 tween(extra, 0.25, { Size = UDim2.new(1, 0, 0, open and panelHeight() or 0) })
 if open and not Prism.ReduceMotion then
 -- Options cascade in from the left.
 for _, b in pairs(buttons) do
 local i = b.Button.LayoutOrder
 b.Label.TextTransparency = 1
 b.Label.Position = UDim2.fromOffset(14, 0)
 task.delay(math.min(i, 10) * 0.018, function()
 tween(b.Label, 0.25, { TextTransparency = 0, Position = UDim2.fromOffset(7, 0) })
 end)
 end
 end
 end

 function dropdown:Set(value, silent)
 if multi then
 self.Value = typeof(value) == "table" and table.clone(value) or { value }
 else
 self.Value = value
 end
 render()
 if not silent then safeCall(opts.Callback, self.Value) end
 end
 function dropdown:Get() return self.Value end

 function dropdown:Refresh(options, keepValue)
 self.Options = options or {}
 for _, b in pairs(buttons) do b.Button:Destroy() end
 table.clear(buttons)
 for i, option in ipairs(self.Options) do
 local button = new("TextButton", {
 Size = UDim2.new(1, -3, 0, OPTION_H),
 BackgroundColor3 = Theme.Element,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 LayoutOrder = i,
 Parent = list,
 }, { corner(3) })
 local label = new("TextLabel", {
 Position = UDim2.fromOffset(7, 0),
 Size = UDim2.new(1, -28, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = tostring(option),
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = button,
 })
 local check = icon("check", 11, Theme.Accent, {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -7, 0.5, 0),
 ImageTransparency = 1,
 Parent = button,
 })
 bindAccent(check, "ImageColor3")
 buttons[option] = { Button = button, Label = label, Check = check }

 button.MouseEnter:Connect(function()
 if not isSelected(option) then tween(label, 0.1, { TextColor3 = Theme.Text }) end
 end)
 button.MouseLeave:Connect(function()
 if not isSelected(option) then tween(label, 0.1, { TextColor3 = Theme.SubText }) end
 end)
 button.MouseButton1Click:Connect(function()
 playSound("Click", 1.1)
 if multi then
 local idx = table.find(dropdown.Value, option)
 if idx then table.remove(dropdown.Value, idx) else table.insert(dropdown.Value, option) end
 render()
 safeCall(opts.Callback, dropdown.Value)
 else
 dropdown:Set(option)
 dropdown:SetOpen(false)
 end
 end)
 end
 if multi then
 for i = #self.Value, 1, -1 do
 if not table.find(self.Options, self.Value[i]) then table.remove(self.Value, i) end
 end
 elseif self.Value ~= nil and not table.find(self.Options, self.Value) and not keepValue then
 self.Value = nil
 end
 searchBox.Text = ""
 layoutPanel()
 render()
 if self.Open then self:SetOpen(true) end
 end
 dropdown.SetValues = dropdown.Refresh
 function dropdown:AddOption(option)
 if table.find(self.Options, option) then return end
 local list = table.clone(self.Options)
 table.insert(list, option)
 self:Refresh(list, true)
 end
 function dropdown:RemoveOption(option)
 local list = table.clone(self.Options)
 local i = table.find(list, option)
 if i then
 table.remove(list, i)
 self:Refresh(list)
 end
 end

 searchBox:GetPropertyChangedSignal("Text"):Connect(function()
 local q = string.lower(searchBox.Text)
 for option, b in pairs(buttons) do
 b.Button.Visible = q == "" or string.find(string.lower(tostring(option)), q, 1, true) ~= nil
 end
 if dropdown.Open then dropdown:SetOpen(true) end
 end)

 rowHitbox(self, row, body, opts.Description).MouseButton1Click:Connect(function()
 if dropdown.Locked then return end
 dropdown:SetOpen(not dropdown.Open)
 end)

 -- Options may be a function: it's re-read every OptionsInterval seconds
 -- (default 1) and the list refreshes when its result changes.
 local optionSource = type(opts.Options) == "function" and opts.Options or nil
 if optionSource then
 local ok, list = pcall(optionSource)
 dropdown:Refresh(ok and type(list) == "table" and list or {})
 else
 dropdown:Refresh(opts.Options or {})
 end
 if opts.Default ~= nil then dropdown:Set(opts.Default, true) end
 registerFlag(opts.Flag, dropdown)
 self.Window:_depends(dropdown, opts)
 if optionSource then
 self.Window:_bind(dropdown, optionSource, {
 Interval = opts.OptionsInterval or 1,
 Apply = function(list)
 if type(list) == "table" then dropdown:Refresh(list, true) end
 end,
 })
 end
 return dropdown
end

-- Player dropdown: a Dropdown of the other players that keeps itself up to
-- date as people join and leave.
function Section:PlayerDropdown(opts)
 local function names()
 local out = {}
 for _, p in ipairs(Players:GetPlayers()) do
 if p ~= LocalPlayer or opts.IncludeSelf then table.insert(out, p.Name) end
 end
 table.sort(out)
 return out
 end
 opts.Options = names()
 opts.Placeholder = opts.Placeholder or "Select player"
 local dropdown = self:Dropdown(opts)
 local function refresh() task.defer(function() dropdown:Refresh(names()) end) end
 table.insert(self.Window._conns, Players.PlayerAdded:Connect(refresh))
 table.insert(self.Window._conns, Players.PlayerRemoving:Connect(refresh))
 return dropdown
end

-- Colour picker -------------------------------------------------------------
-- ColorPicker{ Name, Description, Default = Color3, Flag, Callback(color) }
function Section:ColorPicker(opts)
 local row, body, title = baseRow(self, opts, UDim2.new(1, -48, 0, 0))

 local swatch = new("Frame", swatchProps())
 swatch.BorderSizePixel = 0
 swatch.Parent = body
 corner(3).Parent = swatch
 outline(0.8).Parent = swatch

 local colorPicker = element(row, title, body)
 local picker = buildPicker(self, row, swatch, opts.Default, function(color)
 colorPicker.Value = color
 safeCall(opts.Callback, color)
 end)
 colorPicker.Value = picker.Value

 function colorPicker:Set(color, silent)
 picker:Set(color, silent)
 self.Value = picker.Value
 end
 function colorPicker:Get() return self.Value end
 function colorPicker:SetOpen(open) picker:SetOpen(open) end

 rowHitbox(self, row, body, opts.Description).MouseButton1Click:Connect(function()
 if colorPicker.Locked then return end
 picker:SetOpen(not picker.Open)
 end)

 registerFlag(opts.Flag, colorPicker)
 self.Window:_depends(colorPicker, opts)
 return colorPicker
end

-- Textbox -------------------------------------------------------------------
-- Textbox{ Name, Description, Placeholder, Default, Numeric, ClearOnEnter, Flag, Callback,
-- MinLength, MaxLength, Pattern, Min, Max, ErrorText, Validate(text) -> ok, message }
-- Invalid input shows a red outline and a message under the row, and the
-- callback doesn't run until it's fixed.
function Section:Textbox(opts)
 local row, body, title = baseRow(self, opts, UDim2.new(0.45, 0, 0, 0))

 local box = new("TextBox", controlProps(UDim2.new(0.55, -8, 0, CONTROL_H)))
 box.BackgroundColor3 = Theme.Input
 box.BorderSizePixel = 0
 box.ClearTextOnFocus = false
 box.FontFace = Fonts.Regular
 box.PlaceholderText = opts.Placeholder or "Type here..."
 box.PlaceholderColor3 = Theme.Muted
 box.Text = opts.Default or ""
 box.TextColor3 = Theme.Text
 box.TextSize = 11
 box.TextTruncate = Enum.TextTruncate.AtEnd
 box.TextXAlignment = Enum.TextXAlignment.Left
 box.Parent = body
 corner(4).Parent = box
 padding(0, 0, 7, 7).Parent = box
 local boxStroke = outline()
 boxStroke.Parent = box

 rowHover(self, row, box, opts.Description)

 local textbox = element(row, title, body)
 textbox.Value = box.Text

 if opts.Numeric then
 box:GetPropertyChangedSignal("Text"):Connect(function()
 local cleaned = box.Text:gsub("[^%d%.%-]", "")
 if cleaned ~= box.Text then box.Text = cleaned end
 end)
 end

 function textbox:Set(text, silent)
 self.Value = tostring(text)
 box.Text = self.Value
 if not silent then safeCall(opts.Callback, opts.Numeric and tonumber(self.Value) or self.Value) end
 end
 function textbox:Get() return self.Value end

 -- Validation
 local errorBar = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 LayoutOrder = 2,
 Parent = row,
 })
 local errorLabel = new("TextLabel", {
 Position = UDim2.fromOffset(8, 0),
 Size = UDim2.new(1, -16, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = "",
 TextColor3 = Theme.Error,
 TextSize = 10,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = errorBar,
 })
 local hasError = false

 local function validate(text)
 if opts.MinLength and #text < opts.MinLength then
 return false, "Needs at least " .. opts.MinLength .. " characters"
 end
 if opts.MaxLength and #text > opts.MaxLength then
 return false, "No more than " .. opts.MaxLength .. " characters"
 end
 if opts.Pattern and text ~= "" and not string.match(text, "^" .. opts.Pattern .. "$") then
 return false, opts.ErrorText or "That doesn't look right"
 end
 if opts.Numeric and text ~= "" then
 local n = tonumber(text)
 if not n then return false, "Must be a number" end
 if opts.Min and n < opts.Min then return false, "Minimum is " .. opts.Min end
 if opts.Max and n > opts.Max then return false, "Maximum is " .. opts.Max end
 end
 if opts.Validate then
 local ok, valid, message = pcall(opts.Validate, text)
 if ok and not valid then return false, message or opts.ErrorText or "Invalid value" end
 end
 return true
 end

 local function showError(message)
 hasError = message ~= nil
 if message then errorLabel.Text = message end
 tween(errorBar, 0.2, { Size = UDim2.new(1, 0, 0, message and 16 or 0) })
 tween(boxStroke, 0.15, {
 Color = message and Theme.Error or Theme.Outline,
 Transparency = message and 0 or Theme.OutlineTransparency,
 })
 end

 box:GetPropertyChangedSignal("Text"):Connect(function()
 -- Clear the error as soon as the input becomes valid.
 if hasError and validate(box.Text) then showError(nil) end
 end)
 box.Focused:Connect(function()
 if not hasError then tween(boxStroke, 0.15, { Color = Theme.Accent, Transparency = 0 }) end
 end)
 box.FocusLost:Connect(function(enter)
 local ok, message = validate(box.Text)
 if not ok then
 showError(message)
 return
 end
 showError(nil)
 textbox:Set(box.Text)
 if opts.ClearOnEnter and enter then box.Text = "" end
 end)
 registerFlag(opts.Flag, textbox)
 self.Window:_depends(textbox, opts)
 return textbox
end

-- Keybind -------------------------------------------------------------------
-- Keybind{ Name, Description, Default, Flag, Callback(key), ChangedCallback(key) }
function Section:Keybind(opts)
 local row, body, title = baseRow(self, opts, UDim2.new(1, -90, 0, 0))

 local keyButton = new("TextButton", controlProps(UDim2.fromOffset(72, CONTROL_H)))
 keyButton.BackgroundColor3 = Theme.Input
 keyButton.BorderSizePixel = 0
 keyButton.AutoButtonColor = false
 keyButton.FontFace = Fonts.Medium
 keyButton.TextColor3 = Theme.SubText
 keyButton.TextSize = 11
 keyButton.TextTruncate = Enum.TextTruncate.AtEnd
 keyButton.Parent = body
 corner(4).Parent = keyButton
 padding(0, 0, 6, 6).Parent = keyButton
 local keyStroke = outline()
 keyStroke.Parent = keyButton

 rowHover(self, row, keyButton, opts.Description)

 local keybind = element(row, title, body)
 keybind.Value = opts.Default
 local listening = false

 local function render()
 keyButton.Text = listening and "..." or (keybind.Value and keybind.Value.Name or "None")
 keyButton.TextColor3 = listening and Theme.Accent or Theme.SubText
 end
 function keybind:Set(key, silent)
 if typeof(key) == "string" then key = Enum.KeyCode[key] end
 self.Value = key
 render()
 if not silent then safeCall(opts.ChangedCallback, key) end
 end
 function keybind:Get() return self.Value end

 function keybind:_stopListening()
 listening = false
 tween(keyStroke, 0.15, { Color = Theme.Outline, Transparency = Theme.OutlineTransparency })
 render()
 end
 keyButton.MouseButton1Click:Connect(function()
 self.Window:_claimListener(keybind)
 listening = true
 tween(keyStroke, 0.15, { Color = Theme.Accent, Transparency = 0 })
 render()
 end)

 table.insert(self.Window._conns, UserInputService.InputBegan:Connect(function(input, processed)
 if listening then
 if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
 listening = false
 self.Window:_releaseListener(keybind)
 tween(keyStroke, 0.15, { Color = Theme.Outline, Transparency = Theme.OutlineTransparency })
 local previous = keybind.Value
 local key = input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil
 keybind:Set(key)
 if key then
 self.Window:_warnKeyConflict(keybind, key, function() keybind:Set(previous) end)
 end
 return
 end
 if not processed and keybind.Value and input.KeyCode == keybind.Value then
 safeCall(opts.Callback, keybind.Value)
 end
 end))

 render()
 keybind._isMenu = opts.Flag == "Prism_MenuKey"
 keybind._changeField = "ChangedCallback"
 table.insert(self.Window._keybinds, keybind)
 registerFlag(opts.Flag, keybind)
 self.Window:_depends(keybind, opts)
 return keybind
end

-- Label / Stat / Paragraph / Divider ----------------------------------------
function Section:Label(text)
 local label = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = text or "",
 TextColor3 = Theme.SubText,
 TextSize = 12,
 RichText = true,
 TextWrapped = true,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 }, { padding(5, 5, 8, 8) })
 return {
 Frame = label,
 Set = function(_, t) label.Text = t end,
 SetText = function(_, t) label.Text = t end,
 }
end

-- A name/value line for live info ("Status : Farming boss").
-- Stat{ Name, Value, Icon } -> :Set(value), :SetColor(color)
function Section:Stat(opts)
 if typeof(opts) == "string" then opts = { Name = opts } end
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, 22),
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 })
 local x = 8
 if resolveIcon(opts.Icon) then
 icon(opts.Icon, 12, Theme.Muted, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 8, 0.5, 0),
 Parent = holder,
 })
 x = 26
 end
 new("TextLabel", {
 Position = UDim2.fromOffset(x, 0),
 Size = UDim2.new(0.5, -x, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Name or "",
 TextColor3 = Theme.SubText,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = holder,
 })
 local value = new("TextLabel", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -8, 0, 0),
 Size = UDim2.new(0.5, -8, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = tostring(opts.Value or "-"),
 TextColor3 = Theme.Text,
 TextSize = 12,
 RichText = true,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Right,
 Parent = holder,
 })
 self.Window:_indexElement(opts.Name, self, holder)
 local stat = {
 Frame = holder,
 Set = function(_, v) value.Text = tostring(v) end,
 SetColor = function(_, c) value.TextColor3 = c end,
 }
 self.Window:_depends(stat, opts)
 return stat
end

function Section:Paragraph(opts)
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 }, {
 padding(5, 6, 8, 8),
 new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
 })
 local title = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = opts.Title or "",
 TextColor3 = Theme.Text,
 TextSize = 12,
 RichText = true,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 1,
 Parent = holder,
 })
 local content = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Content or "",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 RichText = true,
 TextWrapped = true,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 2,
 Parent = holder,
 })
 local paragraph = {
 Frame = holder,
 Set = function(_, t, c)
 if t then title.Text = t end
 if c then content.Text = c end
 end,
 SetTitle = function(_, t) title.Text = t end,
 SetContent = function(_, c) content.Text = c end,
 }
 self.Window:_depends(paragraph, opts)
 return paragraph
end

-- Thin line, optionally with a caption.
function Section:Divider(text)
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, text and 20 or 7),
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 })
 new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 8, 0.5, 0),
 Size = UDim2.new(1, -16, 0, 1),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 Parent = holder,
 })
 if text then
 new("TextLabel", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(0, 14),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 FontFace = Fonts.SemiBold,
 Text = string.upper(text),
 TextColor3 = Theme.Muted,
 TextSize = 9,
 Parent = holder,
 }, { padding(0, 0, 6, 6) })
 end
 return { Frame = holder }
end

-- Segmented -----------------------------------------------------------------
-- Segmented{ Name, Description, Options, Default, Flag, Callback }
-- A pill selector for 2-4 choices; the highlight slides between them.
function Section:Segmented(opts)
 local options = opts.Options or {}
 local n = math.max(#options, 1)
 local row, body, title = baseRow(self, opts, UDim2.new(1, -8, 0, 0))
 body.Size = UDim2.new(1, 0, 0, 20)
 title.Position = UDim2.fromOffset(8, 2)

 local extra = new("Frame", {
 Size = UDim2.new(1, 0, 0, 30),
 BackgroundTransparency = 1,
 LayoutOrder = 2,
 Parent = row,
 })
 local bar = new("Frame", {
 Position = UDim2.fromOffset(8, 3),
 Size = UDim2.new(1, -16, 0, 22),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = extra,
 }, { corner(5), outline() })
 rowHover(self, row, bar, opts.Description)
 local pill = accentFill({
 Position = UDim2.fromOffset(2, 2),
 Size = UDim2.new(1 / n, -4, 1, -4),
 Parent = bar,
 }, 4)

 local seg = element(row, title, body)
 local labels = {}
 for i, option in ipairs(options) do
 local b = new("TextButton", {
 Position = UDim2.fromScale((i - 1) / n, 0),
 Size = UDim2.fromScale(1 / n, 1),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = tostring(option),
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextTruncate = Enum.TextTruncate.AtEnd,
 ZIndex = 3,
 Parent = bar,
 })
 labels[i] = b
 b.MouseButton1Click:Connect(function()
 if seg.Locked then return end
 playSound("Click", 1.05)
 seg:Set(option)
 end)
 end

 function seg:Set(value, silent)
 local idx = table.find(options, value) or 1
 self.Value = options[idx]
 tween(pill, 0.3, { Position = UDim2.new((idx - 1) / n, 2, 0, 2) }, Enum.EasingStyle.Quint)
 for i, b in ipairs(labels) do
 tween(b, 0.2, { TextColor3 = i == idx and WHITE or Theme.SubText })
 end
 if not silent then safeCall(opts.Callback, self.Value) end
 end
 function seg:Get() return self.Value end

 seg:Set(opts.Default or options[1], true)
 registerFlag(opts.Flag, seg)
 self.Window:_depends(seg, opts)
 return seg
end

-- Progress ------------------------------------------------------------------
-- Progress{ Name, Value = 0..1, Text } -> :Set(value, text)
function Section:Progress(opts)
 local holder = new("Frame", {
 Size = UDim2.new(1, 0, 0, 34),
 BackgroundTransparency = 1,
 LayoutOrder = self:_nextOrder(),
 Parent = self.Container,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(8, 4),
 Size = UDim2.new(1, -70, 0, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = opts.Name or "",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = holder,
 })
 local valueLabel = new("TextLabel", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -8, 0, 4),
 Size = UDim2.fromOffset(60, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Right,
 Parent = holder,
 })
 local track = new("Frame", {
 Position = UDim2.fromOffset(8, 24),
 Size = UDim2.new(1, -16, 0, 4),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = holder,
 }, { corner("full"), outline(0.9) })
 local fill = accentFill({ Size = UDim2.fromScale(0, 1), Parent = track })

 local progress = { Frame = holder }
 function progress:Set(value, text)
 self.Value = math.clamp(value or 0, 0, 1)
 tween(fill, 0.35, { Size = UDim2.fromScale(self.Value, 1) }, Enum.EasingStyle.Quad)
 valueLabel.Text = text or (math.floor(self.Value * 100 + 0.5) .. "%")
 end
 progress:Set(opts.Value or 0, opts.Text)
 self.Window:_indexElement(opts.Name, self, holder)
 self.Window:_depends(progress, opts)
 return progress
end

-- ============================================================================
-- TAB
-- ============================================================================
local Tab = {}
Tab.__index = Tab

-- A section card. Returns the stack to fill (header, line, body) and the
-- card itself. Depth comes from a top-lit gradient, a glass edge along the
-- top, and a soft accent spotlight that follows the cursor.
local function sectionCard(column, window)
 local card = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 LayoutOrder = #column:GetChildren(),
 Parent = column,
 }, {
 corner(6),
 outline(),
 new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(196, 196, 206)) }),
 })

 -- Spotlight layer. It has a UIListLayout so the big glow circles can't
 -- grow the card (see LAYOUT RULE); circles hang off a zero-size anchor.
 local layer = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = card,
 }, { new("UIListLayout", {}) })
 local anchor = new("Frame", { Size = UDim2.new(), BackgroundTransparency = 1, Parent = layer })
 local spot = new("Frame", { Size = UDim2.new(), BackgroundTransparency = 1, Parent = anchor })
 local rings = {}
 for i = 1, 6 do
 local d = 30 + i * 34
 rings[i] = bindAccent(new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Size = UDim2.fromOffset(d, d),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 Parent = spot,
 }, { corner("full") }), "BackgroundColor3")
 end
 local function showSpot(on)
 for _, r in ipairs(rings) do
 tween(r, on and 0.25 or 0.4, { BackgroundTransparency = on and 0.993 or 1 })
 end
 end
 card.MouseEnter:Connect(function() if not Prism.ReduceMotion then showSpot(true) end end)
 card.MouseLeave:Connect(function() showSpot(false) end)
 card.MouseMoved:Connect(function()
 local rel = (mouseAbsolute() - layer.AbsolutePosition) / window:_layoutScale()
 spot.Position = UDim2.fromOffset(rel.X, rel.Y)
 end)

 -- Glass edge along the top
 new("Frame", {
 Position = UDim2.fromOffset(12, 0),
 Size = UDim2.new(1, -24, 0, 1),
 BackgroundColor3 = WHITE,
 BackgroundTransparency = 0.94,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = card,
 }, {
 new("UIGradient", {
 Transparency = NumberSequence.new({
 NumberSequenceKeypoint.new(0, 1),
 NumberSequenceKeypoint.new(0.5, 0),
 NumberSequenceKeypoint.new(1, 1),
 }),
 }),
 })

 local stack = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = card,
 }, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
 return stack, card
end

-- Container for a section's rows; padding + list. Returns frame, layout.
local function sectionBody(parent, order)
 local inner = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 LayoutOrder = order or 3,
 Parent = parent,
 }, { padding(4, 4, 4, 4) })
 local layout = new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })
 return inner, layout
end

local function cardLine(card, order)
 return new("Frame", {
 Size = UDim2.new(1, 0, 0, 1),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 LayoutOrder = order or 2,
 Parent = card,
 })
end

-- Tab:Section{ Name, Icon, Side = "Left" | "Right", Collapsed }
-- Sections are cards; click the header to collapse or expand.
function Tab:Section(opts)
 opts = opts or {}
 local window = self.Window
 local column = (opts.Side == "Right") and self.Right or self.Left
 local card = sectionCard(column, window)

 local header = new("TextButton", {
 Size = UDim2.new(1, 0, 0, 28),
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 LayoutOrder = 1,
 Parent = card,
 })
 -- Accent tick on the left edge of the header
 local tick = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 0, 0.5, 0),
 Size = UDim2.fromOffset(2, 12),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = header,
 }, { corner("full") })
 accentGradient(tick, 90)

 local textX = 10
 if resolveIcon(opts.Icon) then
 bindAccent(icon(opts.Icon, 12, Theme.Accent, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 10, 0.5, 0),
 Parent = header,
 }), "ImageColor3")
 textX = 28
 end
 new("TextLabel", {
 Position = UDim2.fromOffset(textX, 0),
 Size = UDim2.new(1, -(textX + 28), 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = opts.Name or "Section",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = header,
 })
 local chevron = icon("chevron-down", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -8, 0.5, 0),
 Parent = header,
 })
 header.MouseEnter:Connect(function() tween(chevron, 0.12, { ImageColor3 = Theme.Text }) end)
 header.MouseLeave:Connect(function() tween(chevron, 0.12, { ImageColor3 = Theme.Muted }) end)

 local line = cardLine(card, 2)

 local content = new("Frame", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 LayoutOrder = 3,
 Parent = card,
 })
 local inner, layout = sectionBody(content, 1)

 local section = setmetatable({
 Container = inner,
 Window = window,
 Tab = self,
 Name = opts.Name,
 Collapsed = false,
 _order = 0,
 }, Section)

 function section:SetCollapsed(collapsed, instant)
 self.Collapsed = collapsed
 local time = instant and 0 or 0.25
 local full = (layout.AbsoluteContentSize.Y / window:_layoutScale()) + 8
 tween(chevron, time, { Rotation = collapsed and -90 or 0 })
 content.AutomaticSize = Enum.AutomaticSize.None
 if collapsed then
 content.Size = UDim2.new(1, 0, 0, full)
 tween(content, time, { Size = UDim2.new(1, 0, 0, 0) })
 line.Visible = false
 else
 line.Visible = true
 tween(content, time, { Size = UDim2.new(1, 0, 0, full) }).Completed:Connect(function()
 if not self.Collapsed then content.AutomaticSize = Enum.AutomaticSize.Y end
 end)
 end
 end

 header.MouseButton1Click:Connect(function() section:SetCollapsed(not section.Collapsed) end)
 if opts.Collapsed then task.defer(function() section:SetCollapsed(true, true) end) end

 return section
end

-- Tab:Tabbox{ Side } -> Tabbox:Tab(name) -> Section
-- A card with its own row of sub-tabs (Linoria style), e.g.
-- "Enemy ESP | ESP Settings". Each sub-tab is a normal Section.
function Tab:Tabbox(opts)
 opts = opts or {}
 local window = self.Window
 local column = (opts.Side == "Right") and self.Right or self.Left
 local card = sectionCard(column, window)

 local bar = new("Frame", {
 Size = UDim2.new(1, 0, 0, 28),
 BackgroundTransparency = 1,
 LayoutOrder = 1,
 Parent = card,
 }, {
 padding(4, 0, 4, 4),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 Padding = UDim.new(0, 4),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 cardLine(card, 2)

 local tabbox = { Tabs = {} }
 local tabTab = self

 local function select(entry)
 for _, other in ipairs(tabbox.Tabs) do
 local on = other == entry
 other.Body.Visible = on
 tween(other.Button, 0.15, { BackgroundTransparency = on and 0 or 1 })
 tween(other.Label, 0.15, { TextColor3 = on and Theme.Text or Theme.Muted })
 tween(other.Underline, 0.2, { Size = UDim2.new(on and 1 or 0, on and -12 or 0, 0, 2) })
 end
 tabbox.Active = entry
 end

 function tabbox:Tab(name)
 local button = new("TextButton", {
 Size = UDim2.new(1, 0, 0, 22),
 BackgroundColor3 = Theme.Element,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 LayoutOrder = #self.Tabs + 1,
 Parent = bar,
 }, { corner(4) })
 local label = new("TextLabel", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = name,
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextTruncate = Enum.TextTruncate.AtEnd,
 Parent = button,
 })
 local underline = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 1),
 Position = UDim2.new(0.5, 0, 1, 0),
 Size = UDim2.new(0, 0, 0, 2),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = button,
 }, { corner("full") })
 accentGradient(underline)

 local body = sectionBody(card, 3)
 body.Visible = false

 local entry = { Button = button, Label = label, Underline = underline, Body = body }
 table.insert(self.Tabs, entry)
 -- Split the bar evenly between the sub-tabs.
 for _, e in ipairs(self.Tabs) do
 e.Button.Size = UDim2.new(1 / #self.Tabs, -4 * (#self.Tabs - 1) / #self.Tabs, 0, 22)
 end
 button.MouseButton1Click:Connect(function() select(entry) end)
 if #self.Tabs == 1 then select(entry) end

 return setmetatable({
 Container = body,
 Window = window,
 Tab = tabTab,
 Name = name,
 Collapsed = false,
 SetCollapsed = function() end,
 _order = 0,
 }, Section)
 end

 return tabbox
end

-- ============================================================================
-- WINDOW
-- ============================================================================
-- +--------------+---------------------------------------------+
-- | <> PRISM | # Main [Search] - x | top bar
-- | Script Hub |---------------------------------------------|
-- |--------------| +-- Section --------+ +-- Section -------+ |
-- | CATEGORY | | Toggle (o ) | | Slider ---o- 50 | |
-- | > Main | | Dropdown [v ] | | Color [##] | |
-- | Visuals | +-------------------+ +------------------+ |
-- | Settings | |
-- |--------------| |
-- | @ Player | |
-- +--------------+---------------------------------------------+
-- ============================================================================
local Window = {}
Window.__index = Window

local function makeDraggable(handle, target, conns)
 local dragging, dragStart, startPos = false, nil, nil
 handle.InputBegan:Connect(function(input)
 if isMouseOrTouch(input) then
 dragging, dragStart, startPos = true, input.Position, target.Position
 end
 end)
 table.insert(conns, UserInputService.InputChanged:Connect(function(input)
 if dragging and isMove(input) then
 local delta = input.Position - dragStart
 target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
 end
 end))
 table.insert(conns, UserInputService.InputEnded:Connect(function(input)
 if isMouseOrTouch(input) then dragging = false end
 end))
end

local SHADOW_TRANSPARENCY = 0.3
local UNDERGLOW_TRANSPARENCY = 0.95
local SIDEBAR, SIDEBAR_COMPACT, TOPBAR = 158, 52, 36

-- Live FPS and ping, shared by the profile card and the watermark.
local stats = { FPS = 60, Ping = 0 }
do
 local frames, last = 0, os.clock()
 table.insert(Prism._libConns, RunService.RenderStepped:Connect(function()
 frames += 1
 local now = os.clock()
 if now - last >= 0.5 then
 stats.FPS = math.floor(frames / (now - last) + 0.5)
 frames, last = 0, now
 local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
 if ok and ping then stats.Ping = math.floor(ping * 1000 + 0.5) end
 end
 end))
end

-- Prism:CreateWindow{ Title, Subtitle, Footer, ToggleKey, Size, Columns,
-- Scale, Intro, IntroTitle, Tagline, IntroSteps,
-- ConfigFolder }
-- Size defaults to 640x460, Columns to 2, Scale to 1 (the window only
-- ever shrinks to fit small screens).
function Prism:CreateWindow(opts)
 opts = opts or {}
 local self = setmetatable({}, Window)
 self._conns = {}
 self._index = {}
 self._bindables = {}
 self._keybinds = {} -- Keybind elements, for conflict checks
 self._bindings = {} -- live data bindings, see Window:_bind
 self._unloadHooks = {}
 self._attached = {}
 self._deps = {}
 self._compactHide = {}
 self.Tabs = {}
 -- Live loading status for the intro (Window:SetLoading / FinishLoading).
 self._manualLoading = opts.ManualLoading
 self._loadingState = { Text = "Loading...", Progress = 0 }
 Prism._windows = Prism._windows or {}
 table.insert(Prism._windows, self)
 self.Visible = true
 self.Title = opts.Title or "Prism"
 self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
 -- Configs live in / so every game keeps its own
 -- set. PerGameConfigs = false shares one folder across games.
 self.ConfigFolder = opts.ConfigFolder or "Prism"
 if opts.PerGameConfigs ~= false then
 self.ConfigFolder = self.ConfigFolder .. "/" .. tostring(game.GameId)
 end
 self.Columns = opts.Columns or 2
 local size = opts.Size or Vector2.new(640, 460)
 local width, height = size.X, size.Y
 self._width, self._height = width, height
 self.User = opts.User
 self._homeConfig = opts.Home
 self._started = os.clock()
 local useIntro = opts.Intro ~= false

 local gui = new("ScreenGui", {
 Name = "Prism",
 ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
 IgnoreGuiInset = true,
 ResetOnSpawn = false,
 DisplayOrder = 999,
 })
 guiParent(gui)
 self.Gui = gui

 local root = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(width, height),
 BackgroundTransparency = 1,
 ZIndex = 2,
 Parent = gui,
 })
 self.Root = root

 -- BaseScale is the wanted scale capped so the window always fits on
 -- screen. Every scale animation is relative to it.
 local camera = workspace.CurrentCamera
 self._userScale = opts.Scale
 local function fitScale()
 local viewport = camera.ViewportSize
 local want = self._userScale or 1
 return math.min(want, (viewport.X - 40) / self._width, (viewport.Y - 40) / self._height)
 end
 self._fitScale = fitScale
 self.BaseScale = fitScale()
 self.RootScale = new("UIScale", { Scale = self.BaseScale, Parent = root })
 table.insert(self._conns, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
 self.BaseScale = fitScale()
 if self.Visible then self.RootScale.Scale = self.BaseScale end
 end))

 -- Accent underglow: a wide, faint halo of the accent colour under the
 -- window, behind the drop shadow.
 self.Underglow = bindAccent(new("ImageLabel", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.new(0.5, 0, 0.5, 20),
 Size = UDim2.new(1, 160, 1, 160),
 BackgroundTransparency = 1,
 Image = "rbxassetid://8992230677",
 ScaleType = Enum.ScaleType.Slice,
 SliceCenter = Rect.new(99, 99, 99, 99),
 ImageTransparency = UNDERGLOW_TRANSPARENCY,
 Parent = root,
 }), "ImageColor3")
 self.Shadow = dropShadow(root, "Window")

 local main = new("CanvasGroup", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Theme.Background,
 BorderSizePixel = 0,
 Parent = root,
 }, { corner(10) })
 self.Main = main

 -- Ambient aurora: two soft accent blobs drifting slowly behind the
 -- content. Fake radial falloff from stacked faint circles.
 local aurora = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = main,
 })
 local blobs = {}
 for b = 1, 2 do
 local blob = new("Frame", { Size = UDim2.new(), BackgroundTransparency = 1, Parent = aurora })
 for i = 1, 6 do
 local d = 60 + i * 52
 bindAccent(new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Size = UDim2.fromOffset(d, d),
 BackgroundTransparency = b == 1 and 0.978 or 0.984,
 BorderSizePixel = 0,
 Parent = blob,
 }, { corner("full") }), "BackgroundColor3")
 end
 blobs[b] = blob
 end
 tickers[aurora] = function(t)
 if not aurora.Parent then
 tickers[aurora] = nil
 return
 end
 if Prism.ReduceMotion then t = 0 end
 blobs[1].Position = UDim2.fromScale(0.78 + 0.1 * math.sin(t * 0.21), 0.18 + 0.1 * math.cos(t * 0.29))
 blobs[2].Position = UDim2.fromScale(0.42 + 0.14 * math.cos(t * 0.17), 0.9 + 0.07 * math.sin(t * 0.25))
 end

 local function hline(parent, y, x)
 return new("Frame", {
 Position = UDim2.new(0, x or 0, 0, y),
 Size = UDim2.new(1, -(x or 0) * 2, 0, 1),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 ZIndex = 2,
 Parent = parent,
 })
 end

 -- Sidebar ---------------------------------------------------------------
 local sidebar = new("Frame", {
 Size = UDim2.new(0, SIDEBAR, 1, 0),
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 ClipsDescendants = true,
 Parent = main,
 })
 self._sidebar = sidebar
 new("Frame", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.fromScale(1, 0),
 Size = UDim2.new(0, 1, 1, 0),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 ZIndex = 3,
 Parent = sidebar,
 })

 local brand = new("Frame", {
 Size = UDim2.new(1, 0, 0, 52),
 BackgroundTransparency = 1,
 Parent = sidebar,
 })
 makeDraggable(brand, root, self._conns)
 -- Accent wash behind the logo, fading right
 local wash = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 0.82,
 BorderSizePixel = 0,
 Parent = brand,
 }, { new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
 bindAccent(wash, "BackgroundColor3")
 -- Faint crystal facet lines
 for i, spec in ipairs({ { 0.62, 58 }, { 0.82, 64 } }) do
 new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.new(spec[1], 0, 0.5, 0),
 Size = UDim2.fromOffset(110, 1),
 Rotation = spec[2],
 BackgroundColor3 = WHITE,
 BackgroundTransparency = 0.94 + i * 0.015,
 BorderSizePixel = 0,
 Parent = brand,
 })
 end

 self.LogoSlot = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 12, 0.5, 0),
 Size = UDim2.fromOffset(28, 28),
 BackgroundTransparency = 1,
 Parent = brand,
 })
 self.BrandTitle = new("TextLabel", {
 Position = UDim2.fromOffset(48, 13),
 Size = UDim2.new(1, -54, 0, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(self.Title),
 TextColor3 = Theme.Text,
 TextSize = 13,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = brand,
 })
 self.BrandSubtitle = new("TextLabel", {
 Position = UDim2.fromOffset(48, 28),
 Size = UDim2.new(1, -54, 0, 12),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Subtitle or "Script Hub",
 TextColor3 = Theme.Muted,
 TextSize = 10,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = brand,
 })
 hline(sidebar, 52)
 table.insert(self._compactHide, self.BrandTitle)
 table.insert(self._compactHide, self.BrandSubtitle)

 -- Tab list with a sliding indicator behind the active tab
 local PROFILE = 46
 self.TabIndicator = new("Frame", {
 Size = UDim2.new(1, -16, 0, 28),
 Position = UDim2.fromOffset(8, -40),
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 Parent = sidebar,
 }, { corner(5), outline() })
 local indicatorBar = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 0, 0.5, 0),
 Size = UDim2.fromOffset(2, 14),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = self.TabIndicator,
 }, { corner("full") })
 accentGradient(indicatorBar, 90)
 -- Accent tint across the active tab, fading out to the right.
 bindAccent(new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 0.84,
 BorderSizePixel = 0,
 Parent = self.TabIndicator,
 }, { corner(5), new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) }), "BackgroundColor3")

 self.TabList = new("ScrollingFrame", {
 Position = UDim2.fromOffset(8, 60),
 Size = UDim2.new(1, -16, 1, -(60 + PROFILE + 6)),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ScrollBarThickness = 0,
 ScrollingDirection = Enum.ScrollingDirection.Y,
 CanvasSize = UDim2.new(),
 AutomaticCanvasSize = Enum.AutomaticSize.Y,
 ZIndex = 2,
 Parent = sidebar,
 }, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
 self._tabOrder = 0

 local indicatorY
 table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)
 local active = self.ActiveTab
 if not active or not root.Visible then return end
 -- Tabs without a sidebar button (Home) have nothing to point at.
 if not active.Button.Visible then
 self.TabIndicator.Visible = false
 indicatorY = nil
 return
 end
 local s = self:_layoutScale()
 local y = (active.Button.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) / s
 indicatorY = indicatorY and lerp(indicatorY, y, math.min(1, dt * 16)) or y
 self.TabIndicator.Position = UDim2.fromOffset(8, indicatorY)
 -- Hide it if the active tab is scrolled out of the list.
 local listTop = (self.TabList.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) / s
 local listBottom = listTop + self.TabList.AbsoluteSize.Y / s
 self.TabIndicator.Visible = indicatorY > listTop - 20 and indicatorY < listBottom
 end))

 -- Profile card
 local profile = new("Frame", {
 AnchorPoint = Vector2.new(0, 1),
 Position = UDim2.fromScale(0, 1),
 Size = UDim2.new(1, 0, 0, PROFILE),
 BackgroundTransparency = 1,
 Parent = sidebar,
 })
 hline(profile, 0)

 -- The profile card opens the Home dashboard.
 local profileHit = new("TextButton", {
 Position = UDim2.fromOffset(6, 5),
 Size = UDim2.new(1, -12, 1, -10),
 BackgroundColor3 = Theme.Element,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 Parent = profile,
 }, { corner(6) })
 local profileChevron = icon("chevron-right", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -8, 0.5, 0),
 ImageTransparency = 0.5,
 Parent = profileHit,
 })
 profileHit.MouseEnter:Connect(function()
 tween(profileHit, 0.12, { BackgroundTransparency = 0 })
 tween(profileChevron, 0.12, { ImageTransparency = 0, Position = UDim2.new(1, -5, 0.5, 0) })
 end)
 profileHit.MouseLeave:Connect(function()
 tween(profileHit, 0.15, { BackgroundTransparency = 1 })
 tween(profileChevron, 0.15, { ImageTransparency = 0.5, Position = UDim2.new(1, -8, 0.5, 0) })
 end)
 profileHit.MouseButton1Click:Connect(function()
 playSound("Click", 1.2)
 self:OpenHome()
 end)
 local avatar = new("ImageLabel", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 12, 0.5, 0),
 Size = UDim2.fromOffset(26, 26),
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 Parent = profile,
 }, { corner("full"), outline(0.85) })
 task.spawn(function()
 local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
 if ok then avatar.Image = img end
 end)
 new("Frame", {
 AnchorPoint = Vector2.new(1, 1),
 Position = UDim2.fromScale(1, 1),
 Size = UDim2.fromOffset(8, 8),
 BackgroundColor3 = Theme.Success,
 BorderSizePixel = 0,
 Parent = avatar,
 }, { corner("full"), stroke(Theme.Surface, 2, 0) })
 new("TextLabel", {
 Position = UDim2.fromOffset(46, 8),
 Size = UDim2.new(1, -52, 0, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = LocalPlayer.DisplayName,
 TextColor3 = Theme.Text,
 TextSize = 11,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = profile,
 })
 table.insert(self._compactHide, profile:FindFirstChildWhichIsA("TextLabel"))
 table.insert(self._compactHide, profileChevron)
 local subRow = new("Frame", {
 Position = UDim2.fromOffset(46, 24),
 Size = UDim2.new(1, -52, 0, 13),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = profile,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 5),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 table.insert(self._compactHide, subRow)
 -- Tier badge, e.g. User = { Tag = "Premium" }
 if self.User and self.User.Tag then
 local badge = accentFill({
 Size = UDim2.fromOffset(0, 12),
 AutomaticSize = Enum.AutomaticSize.X,
 LayoutOrder = 1,
 Parent = subRow,
 }, 3)
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 12),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(self.User.Tag),
 TextColor3 = WHITE,
 TextSize = 8,
 ZIndex = 2,
 Parent = badge,
 }, { padding(0, 0, 4, 4) })
 end
 local subLine = new("TextLabel", {
 Size = UDim2.fromOffset(0, 13),
 AutomaticSize = Enum.AutomaticSize.X,
 LayoutOrder = 2,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = (self.User and self.User.Expiry) or opts.Footer or ("v" .. Prism.Version),
 TextColor3 = Theme.Muted,
 TextSize = 10,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = subRow,
 })
 self.FooterLabel = subLine

 -- Top bar ---------------------------------------------------------------
 local topbar = new("Frame", {
 Position = UDim2.fromOffset(SIDEBAR, 0),
 Size = UDim2.new(1, -SIDEBAR, 0, TOPBAR),
 BackgroundTransparency = 1,
 Parent = main,
 })
 makeDraggable(topbar, root, self._conns)
 hline(topbar, TOPBAR - 1)
 self._topbar = topbar

 -- Collapse the sidebar to icons only.
 local compactButton = new("TextButton", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 8, 0.5, 0),
 Size = UDim2.fromOffset(24, 24),
 BackgroundColor3 = Theme.ElementHover,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 Parent = topbar,
 }, { corner(5) })
 local compactIcon = icon("menu", 13, Theme.Muted, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = compactButton,
 })
 compactButton.MouseEnter:Connect(function()
 tween(compactButton, 0.12, { BackgroundTransparency = 0 })
 tween(compactIcon, 0.12, { ImageColor3 = Theme.Text })
 self:_showTooltip(self.Compact and "Expand sidebar" or "Compact sidebar")
 end)
 compactButton.MouseLeave:Connect(function()
 tween(compactButton, 0.12, { BackgroundTransparency = 1 })
 tween(compactIcon, 0.12, { ImageColor3 = Theme.Muted })
 self:_hideTooltip()
 end)
 compactButton.MouseButton1Click:Connect(function()
 playSound("Click", 1.1)
 local flag = Prism.Flags.Prism_Compact
 if flag then flag:Set(not self.Compact) else self:SetCompact(not self.Compact) end
 end)

 self.PageIcon = icon(nil, 13, Theme.Accent, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 40, 0.5, 0),
 Parent = topbar,
 })
 bindAccent(self.PageIcon, "ImageColor3")
 local titleRow = new("Frame", {
 Position = UDim2.fromOffset(60, 0),
 Size = UDim2.new(1, -258, 1, 0),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = topbar,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 8),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 self.PageTitle = new("TextLabel", {
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = "",
 TextColor3 = Theme.Text,
 TextSize = 13,
 LayoutOrder = 1,
 Parent = titleRow,
 })
 self.PageDesc = new("TextLabel", {
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 LayoutOrder = 2,
 Parent = titleRow,
 })

 local function topButton(iconName, offset, onClick)
 local b = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, offset, 0.5, 0),
 Size = UDim2.fromOffset(24, 24),
 BackgroundColor3 = Theme.ElementHover,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 Parent = topbar,
 }, { corner(5) })
 local img = icon(iconName, 13, Theme.Muted, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = b,
 })
 b.MouseEnter:Connect(function()
 tween(b, 0.12, { BackgroundTransparency = 0 })
 tween(img, 0.12, { ImageColor3 = Theme.Text })
 end)
 b.MouseLeave:Connect(function()
 tween(b, 0.12, { BackgroundTransparency = 1 })
 tween(img, 0.12, { ImageColor3 = Theme.Muted })
 end)
 b.MouseButton1Click:Connect(onClick)
 return b
 end
 topButton("x", -8, function()
 self:Dialog({
 Title = "Unload " .. self.Title .. "?",
 Content = "Turns every feature off and removes the UI. Use minimise to just hide it.",
 Icon = "power",
 Buttons = {
 { Title = "Cancel" },
 { Title = "Unload", Primary = true, Callback = function() self:Unload() end },
 },
 })
 end)
 topButton("minus", -34, function() self:Minimize() end)

 local searchPill = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -64, 0.5, 0),
 Size = UDim2.fromOffset(132, 24),
 BackgroundColor3 = Theme.Input,
 AutoButtonColor = false,
 Text = "",
 Parent = topbar,
 }, { corner(5), outline() })
 icon("search", 12, Theme.Muted, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 8, 0.5, 0),
 Parent = searchPill,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(26, 0),
 Size = UDim2.new(1, -70, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "Search",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = searchPill,
 })
 chip({
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -4, 0.5, 0),
 Size = UDim2.fromOffset(38, 16),
 Text = "Ctrl K",
 Parent = searchPill,
 }).TextSize = 9
 searchPill.MouseEnter:Connect(function() tween(searchPill, 0.12, { BackgroundColor3 = Theme.Element }) end)
 searchPill.MouseLeave:Connect(function() tween(searchPill, 0.12, { BackgroundColor3 = Theme.Input }) end)
 searchPill.MouseButton1Click:Connect(function() self:OpenSearch() end)

 -- Pages -----------------------------------------------------------------
 self.Pages = new("Frame", {
 Position = UDim2.fromOffset(SIDEBAR, TOPBAR),
 Size = UDim2.new(1, -SIDEBAR, 1, -TOPBAR),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = main,
 })

 -- Window rim: a hairline around the window, styled by SetBorderStyle.
 -- Inset 1px because the CanvasGroup clips its own bounds.
 local rim = new("Frame", {
 Position = UDim2.fromOffset(1, 1),
 Size = UDim2.new(1, -2, 1, -2),
 BackgroundTransparency = 1,
 ZIndex = 10,
 Parent = main,
 }, { corner(9) })
 self._rimStroke = stroke(WHITE, 1, 0)
 self._rimStroke.Parent = rim
 self._rimGradient = new("UIGradient", { Rotation = 90, Parent = self._rimStroke })
 self:SetBorderStyle(opts.BorderStyle or "Subtle")

 -- Resize grip, bottom-right. The window grows down and right; its top-left
 -- corner stays put.
 local grip = new("TextButton", {
 AnchorPoint = Vector2.new(1, 1),
 Position = UDim2.new(1, -3, 1, -3),
 Size = UDim2.fromOffset(14, 14),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 11,
 Parent = main,
 })
 for i, xy in ipairs({ { 10, 4 }, { 10, 10 }, { 4, 10 } }) do
 new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromOffset(xy[1], xy[2]),
 Size = UDim2.fromOffset(2, 2),
 BackgroundColor3 = Theme.Muted,
 BorderSizePixel = 0,
 Parent = grip,
 }, { corner("full") })
 end
 local resizing, resizeStart, startW, startH, startPos
 grip.InputBegan:Connect(function(input)
 if isMouseOrTouch(input) then
 resizing, resizeStart = true, input.Position
 startW, startH, startPos = self._width, self._height, root.Position
 end
 end)
 table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
 if not (resizing and isMove(input)) then return end
 local s = self:_layoutScale()
 local delta = (input.Position - resizeStart) / s
 local w = math.clamp(startW + delta.X, 540, 1100)
 local h = math.clamp(startH + delta.Y, 360, 860)
 self._width, self._height = w, h
 root.Size = UDim2.fromOffset(w, h)
 root.Position = startPos + UDim2.fromOffset((w - startW) * s / 2, (h - startH) * s / 2)
 end))
 table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
 if isMouseOrTouch(input) then resizing = false end
 end))

 -- Tooltip (outside the window so it isn't clipped or scaled)
 self._tooltip = new("TextLabel", {
 Size = UDim2.fromOffset(0, 22),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 FontFace = Fonts.Regular,
 Text = "",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 RichText = true,
 Visible = false,
 ZIndex = 50,
 Parent = gui,
 }, { corner(4), outline(0.85), padding(0, 0, 8, 8) })
 table.insert(self._conns, RunService.RenderStepped:Connect(function()
 if self._tooltip.Visible then
 local m = UserInputService:GetMouseLocation()
 self._tooltip.Position = UDim2.fromOffset(m.X + 14, m.Y + 12)
 end
 end))

 self:_buildSearch()
 self:_addDefaultCommands()

 table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, processed)
 if input.KeyCode == Enum.KeyCode.K
 and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
 if self.Visible then self:OpenSearch() end
 return
 end
 if input.KeyCode == Enum.KeyCode.Escape and self._searchOpen then
 self:CloseSearch()
 return
 end
 if not processed and input.KeyCode == self.ToggleKey then
 self:SetVisible(not self.Visible)
 end
 end))

 onThemeChanged(self, function()
 if self.ActiveTab then self.ActiveTab:_setActive(true) end
 end)

 if useIntro then
 main.GroupTransparency = 1
 self.Shadow.ImageTransparency = 1
 self.Underglow.ImageTransparency = 1
 self.RootScale.Scale = self.BaseScale * 0.94
 root.Visible = false

 -- Empty diamond socket the logo flies into. The brand text stays
 -- hidden until the logo lands, then slides out from behind it.
 local socketSide = math.floor(LOGO_RADIUS * (self.LogoSlot.Size.X.Offset / LOGO_SIZE) * math.sqrt(2) + 0.5)
 self.Socket = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(socketSide, socketSide),
 Rotation = 45,
 BackgroundTransparency = 1,
 Parent = self.LogoSlot,
 }, { corner(2), stroke(Theme.Stroke, 1.5, 0.2) })
 for _, label in ipairs({ self.BrandTitle, self.BrandSubtitle }) do
 label.TextTransparency = 1
 label.Position -= UDim2.fromOffset(10, 0)
 end

 -- Notifications sent during the intro wait for it to finish.
 Prism._introBusy = true
 task.spawn(function()
 local ok, err = pcall(playIntro, self, {
 Title = opts.IntroTitle or self.Title,
 Tagline = opts.Tagline or "crystal clear scripting",
 Steps = opts.IntroSteps,
 })
 Prism._introBusy = false
 if not ok then
 warn("[Prism] intro failed: " .. tostring(err))
 self:_reveal(0.3)
 end
 end)
 else
 local logo = buildLogo(self.LogoSlot, { Scale = self.LogoSlot.Size.X.Offset / LOGO_SIZE })
 logo.Holder.Position = UDim2.fromScale(0.5, 0.5)
 self.Logo = logo
 end

 return self
end

-- Current on-screen scale of the window (fit-to-screen times any animation).
function Window:_layoutScale()
 local s = self.Root.AbsoluteSize.X / self._width
 return s > 0 and s or 1
end

-- Key capture is exclusive: whoever claims it last is the only element
-- waiting for a key press; the previous one stops listening.
function Window:_claimListener(element)
 local current = self._listener
 if current and current ~= element then current:_stopListening() end
 self._listener = element
end

function Window:_releaseListener(element)
 if self._listener == element then self._listener = nil end
end

function Window:_showTooltip(text)
 if not Prism.Tooltips then return end
 local token = {}
 self._tooltipToken = token
 task.delay(0.35, function()
 if self._tooltipToken ~= token then return end
 self._tooltip.Text = text
 self._tooltip.Visible = true
 end)
end

function Window:_hideTooltip()
 self._tooltipToken = nil
 self._tooltip.Visible = false
end

function Window:_reveal(time)
 self.Root.Visible = true
 tween(self.Main, time, { GroupTransparency = 0 })
 tween(self.Shadow, time, { ImageTransparency = SHADOW_TRANSPARENCY })
 tween(self.Underglow, time, { ImageTransparency = UNDERGLOW_TRANSPARENCY })
 for _, panel in ipairs(self._attached) do tween(panel, time, { GroupTransparency = 0 }) end
 self:_applyBlur()
 tween(self.RootScale, time, { Scale = self.BaseScale }, Enum.EasingStyle.Back)
end

function Window:_revealBrand()
 for i, label in ipairs({ self.BrandTitle, self.BrandSubtitle }) do
 task.delay((i - 1) * 0.08, function()
 tween(label, 0.5, {
 TextTransparency = 0,
 Position = label.Position + UDim2.fromOffset(10, 0),
 })
 end)
 end
end

function Window:SetVisible(visible)
 self.Visible = visible
 self:_applyBlur()
 if visible and self._pill then self._pill.Visible = false end
 if visible then
 self.RootScale.Scale = self.BaseScale * 0.96
 self:_reveal(0.3)
 else
 if self._searchOpen then self:CloseSearch() end
 self:_hideTooltip()
 tween(self.Main, 0.25, { GroupTransparency = 1 })
 tween(self.Shadow, 0.25, { ImageTransparency = 1 })
 tween(self.Underglow, 0.25, { ImageTransparency = 1 })
 for _, panel in ipairs(self._attached) do tween(panel, 0.25, { GroupTransparency = 1 }) end
 tween(self.RootScale, 0.25, { Scale = self.BaseScale * 0.96 }).Completed:Connect(function()
 if not self.Visible then self.Root.Visible = false end
 end)
 end
end
Window.Toggle = function(self, state) self:SetVisible(state == nil and not self.Visible or state) end

-- Minimise to a small floating pill; click it to restore.
function Window:Minimize()
 self:SetVisible(false)
 if not self._pill then
 local inset = game:GetService("GuiService"):GetGuiInset()
 local pill = new("TextButton", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.new(0.5, 0, 0, inset.Y + 10),
 Size = UDim2.fromOffset(0, 30),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = Theme.Surface,
 AutoButtonColor = false,
 Text = "",
 Parent = self.Gui,
 }, {
 corner("full"),
 outline(0.85),
 padding(0, 0, 8, 12),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 8),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 local logoHolder = new("Frame", {
 Size = UDim2.fromOffset(18, 18),
 BackgroundTransparency = 1,
 LayoutOrder = 1,
 Parent = pill,
 })
 buildLogo(logoHolder, { Scale = 18 / LOGO_SIZE }).Holder.Position = UDim2.fromScale(0.5, 0.5)
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 30),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(self.Title),
 TextColor3 = Theme.Text,
 TextSize = 12,
 LayoutOrder = 2,
 Parent = pill,
 })
 self._pillKey = chip({ Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = pill })
 padding(0, 0, 5, 5).Parent = self._pillKey
 self._pillScale = new("UIScale", { Parent = pill })

 -- Drag it anywhere; a click (no drag) restores the window.
 local downPos
 makeDraggable(pill, pill, self._conns)
 pill.MouseButton1Down:Connect(function() downPos = pill.Position end)
 pill.MouseButton1Click:Connect(function()
 if downPos == pill.Position then self:SetVisible(true) end
 end)
 pill.MouseEnter:Connect(function() tween(pill, 0.12, { BackgroundColor3 = Theme.Element }) end)
 pill.MouseLeave:Connect(function() tween(pill, 0.12, { BackgroundColor3 = Theme.Surface }) end)
 self._pill = pill
 end
 self._pillKey.Text = self.ToggleKey.Name
 self._pill.Visible = true
 self._pillScale.Scale = 0.85
 tween(self._pillScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Background blur while the menu is open.
function Window:SetBlur(on)
 self._blurOn = on
 self:_applyBlur()
end

function Window:_applyBlur()
 local want = self._blurOn and self.Visible
 local blur = Lighting:FindFirstChild("PrismMenuBlur")
 if want and not blur then
 blur = new("BlurEffect", { Name = "PrismMenuBlur", Size = 0, Parent = Lighting })
 end
 if blur then tween(blur, 0.3, { Size = want and 14 or 0 }) end
end

-- Window background opacity, 0..1. Lower values let the game show through
-- (pair with SetBlur for a frosted look).
-- Rim transparency top -> bottom for the static border styles.
local BORDER_STYLES = {
 Subtle = { 0.9, 0.93, 0.95 },
 Glass = { 0.8, 0.9, 0.93 },
}

-- SetBorderStyle("Subtle" | "Glass" | "Accent" | "None")
-- Accent: two soft accent lights orbit the rim; still under ReduceMotion.
function Window:SetBorderStyle(style)
 local rimStroke, g = self._rimStroke, self._rimGradient
 if not (rimStroke and rimStroke.Parent) then return end
 self.BorderStyle = style
 tickers[g] = nil
 themeListeners[g] = nil
 rimStroke.Transparency = style == "None" and 1 or 0
 if style == "Accent" then
 g.Color = accentSequence()
 g.Transparency = NumberSequence.new({
 NumberSequenceKeypoint.new(0, 0.9),
 NumberSequenceKeypoint.new(0.4, 0.9),
 NumberSequenceKeypoint.new(0.5, 0.3),
 NumberSequenceKeypoint.new(0.6, 0.9),
 NumberSequenceKeypoint.new(1, 0.9),
 })
 tickers[g] = function(t)
 if not g.Parent then
 tickers[g] = nil
 return
 end
 if not Prism.ReduceMotion then g.Rotation = (t * 36) % 360 end
 end
 onThemeChanged(g, function()
 if alive(g) then g.Color = accentSequence() else themeListeners[g] = nil end
 end)
 else
 local k = BORDER_STYLES[style] or BORDER_STYLES.Subtle
 g.Color = ColorSequence.new(WHITE)
 g.Rotation = 90
 g.Transparency = NumberSequence.new({
 NumberSequenceKeypoint.new(0, k[1]),
 NumberSequenceKeypoint.new(0.2, k[2]),
 NumberSequenceKeypoint.new(1, k[3]),
 })
 end
end

function Window:SetOpacity(alpha)
 self.Main.BackgroundTransparency = 1 - alpha
 self._sidebar.BackgroundTransparency = (1 - alpha) * 0.6
end

function Window:SetScale(scale)
 self._userScale = scale
 self.BaseScale = self._fitScale()
 if self.Visible then tween(self.RootScale, 0.25, { Scale = self.BaseScale }) end
end

function Window:SetToggleKey(key)
 if typeof(key) == "string" then key = Enum.KeyCode[key] end
 self.ToggleKey = key
end

-- Icons-only sidebar. The content area widens to fill the space.
function Window:SetCompact(on)
 self.Compact = on and true or false
 local w = self.Compact and SIDEBAR_COMPACT or SIDEBAR
 local time = Prism.ReduceMotion and 0 or 0.3
 tween(self._sidebar, time, { Size = UDim2.new(0, w, 1, 0) })
 tween(self._topbar, time, { Position = UDim2.fromOffset(w, 0), Size = UDim2.new(1, -w, 0, TOPBAR) })
 tween(self.Pages, time, { Position = UDim2.fromOffset(w, TOPBAR), Size = UDim2.new(1, -w, 1, -TOPBAR) })
 for _, inst in ipairs(self._compactHide) do
 if inst then inst.Visible = not self.Compact end
 end
end

-- Live loading status for the intro. Pass ManualLoading = true to
-- CreateWindow, then report progress while your script loads:
-- Window:SetLoading("Loading combat module", 0.4)
-- ...
-- Window:FinishLoading() -- or SetLoading(text, 1)
function Window:SetLoading(text, progress)
 local st = self._loadingState
 if text then st.Text = text end
 if progress then st.Progress = math.clamp(progress, 0, 1) end
 if st.Progress >= 1 then self._loadingDone = true end
end

function Window:FinishLoading()
 self._loadingState.Progress = 1
 self._loadingDone = true
end

function Window:SetFooter(text)
 self.FooterLabel.Text = text
end

-- Small heading in the sidebar above the tabs that follow it.
function Window:Category(name)
 self._tabOrder += 1
 local label = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, self._tabOrder == 1 and 18 or 26),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = string.upper(name),
 TextColor3 = Theme.Muted,
 TextSize = 9,
 TextXAlignment = Enum.TextXAlignment.Left,
 TextYAlignment = Enum.TextYAlignment.Bottom,
 LayoutOrder = self._tabOrder,
 Visible = not self.Compact,
 Parent = self.TabList,
 }, { padding(0, 4, 8, 0) })
 table.insert(self._compactHide, label)
end

-- Window:Tab{ Name, Icon }
function Window:Tab(opts)
 opts = opts or {}
 local tab = setmetatable({ Window = self, Name = opts.Name or "Tab", Icon = opts.Icon, Description = opts.Description }, Tab)
 self._tabOrder += 1

 local button = new("TextButton", {
 Size = UDim2.new(1, 0, 0, 28),
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 LayoutOrder = self._tabOrder,
 Parent = self.TabList,
 })
 local tabIcon = icon(opts.Icon or "layout-grid", 14, Theme.Muted, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 10, 0.5, 0),
 Parent = button,
 })
 local label = new("TextLabel", {
 Position = UDim2.fromOffset(32, 0),
 Size = UDim2.new(1, -38, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = tab.Name,
 TextColor3 = Theme.SubText,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Visible = not self.Compact,
 Parent = button,
 })
 table.insert(self._compactHide, label)

 local page = new("ScrollingFrame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ScrollBarThickness = 2,
 ScrollBarImageColor3 = Theme.Muted,
 ScrollingDirection = Enum.ScrollingDirection.Y,
 CanvasSize = UDim2.new(),
 AutomaticCanvasSize = Enum.AutomaticSize.Y,
 Visible = false,
 Parent = self.Pages,
 })

 -- Margins come from this frame's position and size, not a UIPadding on
 -- the ScrollingFrame: Roblox ignored that padding's right side and rows
 -- ran past the window edge.
 local MARGIN, GAP = 10, 10
 local content = new("Frame", {
 Position = UDim2.fromOffset(MARGIN, MARGIN),
 Size = UDim2.new(1, -MARGIN * 2, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = page,
 }, { padding(0, MARGIN, 0, 0) })

 local function column(x, w)
 return new("Frame", {
 Position = UDim2.new(x, x == 0 and 0 or GAP / 2, 0, 0),
 Size = UDim2.new(w, w == 1 and 0 or -GAP / 2, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = content,
 }, { new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }) })
 end
 if self.Columns == 2 then
 tab.Left, tab.Right = column(0, 0.5), column(0.5, 0.5)
 else
 tab.Left = column(0, 1)
 tab.Right = tab.Left
 end
 tab.Page, tab.Button = page, button

 function tab:_setActive(active)
 tween(label, 0.18, { TextColor3 = active and Theme.Text or Theme.SubText })
 tween(tabIcon, 0.18, { ImageColor3 = active and Theme.Accent or Theme.Muted })
 page.Visible = active
 if active then
 self.Window.PageTitle.Text = self.Name
 self.Window.PageDesc.Text = self.Description or ""
 self.Window.PageIcon.Image = resolveIcon(self.Icon or "layout-grid") or ""
 if not Prism.ReduceMotion then
 -- Columns rise in one after the other.
 local cols = { self.Left }
 if self.Right ~= self.Left then table.insert(cols, self.Right) end
 for i, col in ipairs(cols) do
 local home = col:GetAttribute("Home") or col.Position
 col:SetAttribute("Home", home)
 col.Position = home + UDim2.fromOffset(0, 14)
 task.delay((i - 1) * 0.06, function()
 tween(col, 0.4, { Position = home })
 end)
 end
 end
 end
 end

 button.MouseEnter:Connect(function()
 if self.ActiveTab ~= tab then
 tween(label, 0.12, { TextColor3 = Theme.Text })
 tween(tabIcon, 0.12, { ImageColor3 = Theme.Text })
 end
 if self.Compact then self:_showTooltip(tab.Name) end
 end)
 button.MouseLeave:Connect(function()
 if self.ActiveTab ~= tab then
 tween(label, 0.12, { TextColor3 = Theme.SubText })
 tween(tabIcon, 0.12, { ImageColor3 = Theme.Muted })
 end
 self:_hideTooltip()
 end)
 button.MouseButton1Click:Connect(function()
 if self.ActiveTab ~= tab then playSound("Click", 1.2) end
 self:SelectTab(tab)
 end)

 table.insert(self.Tabs, tab)
 self:_indexElement(tab.Name, nil, nil, tab)
 if #self.Tabs == 1 then self:SelectTab(tab) end
 return tab
end

function Window:SelectTab(tab)
 if self.ActiveTab == tab then return end
 -- The hovered element may vanish with the old page and never fire
 -- MouseLeave, so drop any tooltip now.
 self:_hideTooltip()
 if self.ActiveTab then self.ActiveTab:_setActive(false) end
 self.ActiveTab = tab
 tab:_setActive(true)
end

-- ============================================================================
-- COMMAND PALETTE (Ctrl+K)
-- ============================================================================
-- Indexes every tab, every named element and every command.
--
-- Toggles show an ON / OFF chip: click it (or press Enter on the top
-- result) to flip the toggle without leaving the palette.
-- Buttons show a Run chip: runs the button's callback.
-- Commands built-ins (themes, hide, rejoin, unload...) plus anything
-- added with Window:AddCommand{ Name, Icon, Callback }.
-- Anything clicking the row jumps to it: switches tab, opens its
-- section, scrolls to it and flashes it.
-- ============================================================================
function Window:_indexElement(name, section, frame, tab)
 if not name or name == "" then return end
 local entry = {
 Name = name,
 Section = section,
 Frame = frame,
 Tab = tab or (section and section.Tab),
 }
 table.insert(self._index, entry)
 if section then section._lastEntry = entry end
 return entry
end

-- Window:AddCommand{ Name, Icon, Description, Callback }
function Window:AddCommand(opts)
 table.insert(self._index, {
 Name = opts.Name,
 Kind = "Command",
 Icon = opts.Icon or "command",
 Path = opts.Description or "Command",
 Run = opts.Callback,
 })
end

function Window:_buildSearch()
 local overlay = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Color3.new(0, 0, 0),
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 Visible = false,
 ZIndex = 20,
 Parent = self.Main,
 })
 local panel = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.new(0.5, 0, 0, 48),
 Size = UDim2.new(1, -140, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 Active = true,
 Parent = overlay,
 }, {
 corner(10),
 outline(0.85),
 new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
 })
 local panelScale = new("UIScale", { Parent = panel })

 local bar = new("Frame", {
 Size = UDim2.new(1, 0, 0, 38),
 BackgroundTransparency = 1,
 LayoutOrder = 1,
 Parent = panel,
 })
 bindAccent(icon("search", 16, Theme.Accent, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 16, 0.5, 0),
 Parent = bar,
 }), "ImageColor3")
 local input = new("TextBox", {
 Position = UDim2.fromOffset(42, 0),
 Size = UDim2.new(1, -100, 1, 0),
 BackgroundTransparency = 1,
 ClearTextOnFocus = false,
 FontFace = Fonts.Regular,
 PlaceholderText = "Search features or run a command...",
 PlaceholderColor3 = Theme.Muted,
 Text = "",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = bar,
 })
 chip({
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -14, 0.5, 0),
 Size = UDim2.fromOffset(34, 20),
 Text = "Esc",
 Parent = bar,
 }).TextSize = 10
 new("Frame", {
 Size = UDim2.new(1, 0, 0, 1),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 LayoutOrder = 2,
 Parent = panel,
 })
 local results = new("ScrollingFrame", {
 Size = UDim2.new(1, 0, 0, 0),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ScrollBarThickness = 2,
 ScrollBarImageColor3 = Theme.Muted,
 ScrollingDirection = Enum.ScrollingDirection.Y,
 CanvasSize = UDim2.new(),
 AutomaticCanvasSize = Enum.AutomaticSize.Y,
 LayoutOrder = 3,
 Parent = panel,
 }, {
 padding(6, 6, 6, 6),
 new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
 })
 local empty = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 44),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "No results",
 TextColor3 = Theme.Muted,
 TextSize = 13,
 Visible = false,
 LayoutOrder = 4,
 Parent = panel,
 })
 -- Hint strip along the bottom
 local hints = new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 24),
 BackgroundColor3 = Theme.Background,
 BackgroundTransparency = 0.3,
 BorderSizePixel = 0,
 FontFace = Fonts.Regular,
 Text = "Enter to run the top result · Click to jump to it · Esc to close",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 LayoutOrder = 5,
 Parent = panel,
 }, { corner(10) })

 local RESULT_H, MAX_RESULTS = 34, 8
 local first

 local function jump(entry)
 self:CloseSearch()
 if not entry.Tab then return end
 self:SelectTab(entry.Tab)
 if not entry.Frame then return end
 if entry.Section and entry.Section.Collapsed then entry.Section:SetCollapsed(false) end
 task.wait(0.35)
 local page = entry.Tab.Page
 local s = self:_layoutScale()
 local y = (entry.Frame.AbsolutePosition.Y - page.AbsolutePosition.Y) / s + page.CanvasPosition.Y - 40
 tween(page, 0.4, { CanvasPosition = Vector2.new(0, math.max(0, y)) })
 task.wait(0.4)
 -- Flash it so it's easy to spot. The flash floats over the window at
 -- the element's position instead of going inside it: rows have a
 -- UIListLayout that would treat it as another row and grow to fit.
 local s2 = self:_layoutScale()
 local rel = (entry.Frame.AbsolutePosition - self.Main.AbsolutePosition) / s2
 local size = entry.Frame.AbsoluteSize / s2
 local flash = new("Frame", {
 Position = UDim2.fromOffset(rel.X, rel.Y),
 Size = UDim2.fromOffset(size.X, size.Y),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 ZIndex = 15,
 Parent = self.Main,
 }, { corner(6) })
 bindAccent(flash, "BackgroundColor3")
 local ring = stroke(Theme.Accent, 1, 1)
 ring.Parent = flash
 for _ = 1, 3 do
 tween(ring, 0.2, { Transparency = 0.2 })
 tween(flash, 0.2, { BackgroundTransparency = 0.8 }).Completed:Wait()
 tween(ring, 0.25, { Transparency = 1 })
 tween(flash, 0.25, { BackgroundTransparency = 1 }).Completed:Wait()
 end
 flash:Destroy()
 end

 -- Perform an entry's action. Toggles flip in place and keep the palette
 -- open; everything else closes it first.
 local function act(entry)
 if entry.Kind == "Toggle" and entry.Element then
 if entry.Element.Locked then return end
 entry.Element:Set(not entry.Element.Value)
 return true
 end
 if entry.Run then
 self:CloseSearch()
 safeCall(entry.Run)
 return false
 end
 task.spawn(jump, entry)
 return false
 end

 local refresh

 local function chipFor(entry, parent)
 if entry.Kind == "Toggle" and entry.Element then
 local on = entry.Element.Value
 local c = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -8, 0.5, 0),
 Size = UDim2.fromOffset(40, 20),
 BackgroundColor3 = on and Theme.Accent or Theme.Input,
 AutoButtonColor = false,
 FontFace = Fonts.Bold,
 Text = on and "ON" or "OFF",
 TextColor3 = on and WHITE or Theme.Muted,
 TextSize = 10,
 ZIndex = 3,
 Parent = parent,
 }, { corner(5), outline(on and 1 or Theme.OutlineTransparency) })
 c.MouseButton1Click:Connect(function()
 act(entry)
 refresh(true)
 end)
 elseif entry.Run then
 local c = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -8, 0.5, 0),
 Size = UDim2.fromOffset(40, 20),
 BackgroundColor3 = Theme.Input,
 AutoButtonColor = false,
 FontFace = Fonts.Bold,
 Text = "RUN",
 TextColor3 = Theme.SubText,
 TextSize = 10,
 ZIndex = 3,
 Parent = parent,
 }, { corner(5), outline() })
 c.MouseButton1Click:Connect(function() act(entry) end)
 end
 end

 function refresh(keepScroll)
 local scroll = results.CanvasPosition
 for _, c in ipairs(results:GetChildren()) do
 if c:IsA("TextButton") then c:Destroy() end
 end
 local q = string.lower(input.Text)
 local matches = {}
 for _, entry in ipairs(self._index) do
 local name = string.lower(entry.Name)
 local at = q == "" and 1 or string.find(name, q, 1, true)
 -- With no query, list tabs and commands only; typing searches all.
 if at and (q ~= "" or not entry.Frame) then
 local rank = (at == 1 and 0 or 2)
 if entry.Kind == "Command" then rank += 1 end
 if not entry.Frame and entry.Kind ~= "Command" then rank -= 1 end
 table.insert(matches, { Entry = entry, Rank = rank })
 end
 end
 table.sort(matches, function(a, b)
 if a.Rank ~= b.Rank then return a.Rank < b.Rank end
 return a.Entry.Name < b.Entry.Name
 end)

 first = matches[1] and matches[1].Entry
 for i, m in ipairs(matches) do
 if i > 40 then break end
 local entry = m.Entry
 local b = new("TextButton", {
 Size = UDim2.new(1, 0, 0, RESULT_H),
 BackgroundColor3 = Theme.Element,
 BackgroundTransparency = i == 1 and 0 or 1,
 AutoButtonColor = false,
 Text = "",
 LayoutOrder = i,
 Parent = results,
 }, { corner(6) })
 local badge = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 8, 0.5, 0),
 Size = UDim2.fromOffset(22, 22),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = b,
 }, { corner(6), outline() })
 local glyph = entry.Icon
 or (entry.Kind == "Toggle" and "toggle-right")
 or (entry.Run and "chevron-right")
 or (entry.Frame and "hash")
 or (entry.Tab and entry.Tab.Icon)
 or "layout-grid"
 icon(glyph, 12, entry.Kind == "Command" and Theme.Accent or Theme.SubText, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = badge,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(38, 3),
 Size = UDim2.new(1, -100, 0, 15),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = entry.Name,
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = b,
 })
 local path = entry.Path
 or (entry.Frame and entry.Tab and (entry.Tab.Name .. " › " .. ((entry.Section and entry.Section.Name) or "")))
 or "Tab"
 new("TextLabel", {
 Position = UDim2.fromOffset(38, 18),
 Size = UDim2.new(1, -100, 0, 12),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = path,
 TextColor3 = Theme.Muted,
 TextSize = 10,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = b,
 })
 chipFor(entry, b)
 b.MouseEnter:Connect(function() tween(b, 0.1, { BackgroundTransparency = 0 }) end)
 b.MouseLeave:Connect(function() if i ~= 1 then tween(b, 0.1, { BackgroundTransparency = 1 }) end end)
 b.MouseButton1Click:Connect(function()
 if entry.Kind == "Command" then act(entry) else task.spawn(jump, entry) end
 end)
 end
 local shown = math.min(#matches, MAX_RESULTS)
 results.Size = UDim2.new(1, 0, 0, shown > 0 and shown * (RESULT_H + 2) + 12 or 0)
 results.CanvasPosition = keepScroll and scroll or Vector2.zero
 empty.Visible = #matches == 0
 end

 input:GetPropertyChangedSignal("Text"):Connect(function() refresh() end)
 input.FocusLost:Connect(function(enter)
 if not (enter and first and self._searchOpen) then return end
 playSound("Click")
 if act(first) then
 -- Toggle flipped in place: stay open and keep typing.
 refresh(true)
 task.defer(function() input:CaptureFocus() end)
 end
 end)
 overlay.MouseButton1Click:Connect(function() self:CloseSearch() end)

 function self:OpenSearch()
 if self._searchOpen then return end
 self._searchOpen = true
 overlay.Visible = true
 input.Text = ""
 refresh()
 panelScale.Scale = 0.96
 tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
 tween(panelScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
 task.defer(function() input:CaptureFocus() end)
 end

 function self:CloseSearch()
 if not self._searchOpen then return end
 self._searchOpen = false
 input:ReleaseFocus()
 tween(overlay, 0.15, { BackgroundTransparency = 1 }).Completed:Connect(function()
 if not self._searchOpen then overlay.Visible = false end
 end)
 end
end

-- ============================================================================
-- DIALOG
-- ============================================================================
-- Window:Dialog{ Title, Content, Icon, Buttons = { { Title, Primary, Callback } } }
-- ============================================================================
function Window:Dialog(opts)
 local overlay = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Color3.new(0, 0, 0),
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 ZIndex = 30,
 Parent = self.Main,
 })
 local card = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(400, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 Active = true,
 Parent = overlay,
 }, { corner(12), outline(0.85), padding(20, 18, 20, 20) })
 local scale = new("UIScale", { Scale = 0.92, Parent = card })

 local badge = new("Frame", {
 Size = UDim2.fromOffset(38, 38),
 BackgroundTransparency = 0.85,
 BorderSizePixel = 0,
 Parent = card,
 }, { corner(9) })
 bindAccent(badge, "BackgroundColor3")
 bindAccent(icon(opts.Icon or "info", 18, Theme.Accent, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = badge,
 }), "ImageColor3")

 local textCol = new("Frame", {
 Position = UDim2.fromOffset(52, 0),
 Size = UDim2.new(1, -52, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = card,
 }, {
 new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
 new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 20),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = opts.Title or "",
 TextColor3 = Theme.Text,
 TextSize = 16,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 1,
 }),
 new("TextLabel", {
 Size = UDim2.new(1, 0, 0, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Content or "",
 TextColor3 = Theme.SubText,
 TextSize = 13,
 RichText = true,
 TextWrapped = true,
 TextXAlignment = Enum.TextXAlignment.Left,
 LayoutOrder = 2,
 }),
 })

 local buttonRow = new("Frame", {
 Size = UDim2.new(1, 0, 0, 34),
 BackgroundTransparency = 1,
 LayoutOrder = 3,
 Parent = textCol,
 }, {
 padding(12, 0, 0, 0),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 HorizontalAlignment = Enum.HorizontalAlignment.Right,
 Padding = UDim.new(0, 8),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 buttonRow.Size = UDim2.new(1, 0, 0, 46)

 local function close()
 tween(overlay, 0.15, { BackgroundTransparency = 1 })
 tween(scale, 0.15, { Scale = 0.95 })
 card.Visible = false
 task.delay(0.16, function() overlay:Destroy() end)
 end

 for i, spec in ipairs(opts.Buttons or { { Title = "OK", Primary = true } }) do
 -- Fixed width from the text. An auto-sized CanvasGroup fill sized
 -- itself to its full-size inner layers and came out huge.
 local text = spec.Title or "OK"
 local width = math.max(78, #text * 8 + 32)
 local b
 if spec.Primary then
 b = accentFill({ Size = UDim2.fromOffset(width, 32), LayoutOrder = i, Parent = buttonRow }, 7)
 else
 b = new("Frame", {
 Size = UDim2.fromOffset(width, 32),
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 LayoutOrder = i,
 Parent = buttonRow,
 }, { corner(7), outline() })
 end
 new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = text,
 TextColor3 = spec.Primary and WHITE or Theme.Text,
 TextSize = 13,
 ZIndex = 2,
 Parent = b,
 }).MouseButton1Click:Connect(function()
 close()
 safeCall(spec.Callback)
 end)
 end

 overlay.MouseButton1Click:Connect(close)
 tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
 tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
 return { Close = close }
end

-- ============================================================================
-- WATERMARK + KEYBIND LIST
-- ============================================================================
-- Both live outside the window so they stay up while it's hidden, and
-- both can be dragged. They start below Roblox's top bar so they don't
-- cover its buttons.
-- ============================================================================
local function topBarHeight()
 local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
 return ok and inset.Y or 58
end

function Window:SetWatermark(visible)
 if visible and not self._watermark then
 self._wmItems = self._wmItems or { FPS = true, Ping = true, Time = true }
 local pill = new("Frame", {
 Position = UDim2.fromOffset(16, topBarHeight() + 10),
 Size = UDim2.fromOffset(0, 26),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 Active = true,
 Parent = self.Gui,
 }, {
 corner(6),
 outline(0.88),
 padding(0, 0, 6, 10),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 8),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 local logoHolder = new("Frame", {
 Size = UDim2.fromOffset(16, 16),
 BackgroundTransparency = 1,
 LayoutOrder = 1,
 Parent = pill,
 })
 buildLogo(logoHolder, { Scale = 16 / LOGO_SIZE }).Holder.Position = UDim2.fromScale(0.5, 0.5)
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 26),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(self.Title),
 TextColor3 = Theme.Text,
 TextSize = 11,
 LayoutOrder = 2,
 Parent = pill,
 })
 local info = new("TextLabel", {
 Size = UDim2.fromOffset(0, 26),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = "",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 RichText = true,
 LayoutOrder = 3,
 Parent = pill,
 })
 makeDraggable(pill, pill, self._conns)

 self._watermark = pill
 local SEP = ' | '
 task.spawn(function()
 while pill.Parent do
 local parts = {}
 local items = self._wmItems
 if items.FPS then table.insert(parts, stats.FPS .. " fps") end
 if items.Ping then table.insert(parts, stats.Ping .. " ms") end
 if items.Players then table.insert(parts, #Players:GetPlayers() .. " players") end
 if items.Time then table.insert(parts, os.date("%H:%M:%S")) end
 info.Text = #parts > 0 and (SEP:sub(3) .. table.concat(parts, SEP)) or ""
 task.wait(0.5)
 end
 end)
 elseif self._watermark then
 self._watermark.Visible = visible
 end
end

-- Which live readouts the watermark shows: any of "FPS", "Ping", "Time", "Players".
function Window:SetWatermarkItems(list)
 self._wmItems = {}
 for _, name in ipairs(list) do self._wmItems[name] = true end
end

function Window:SetKeybindList(visible)
 self._keybindListOn = visible
 if visible and not self._keybindList then
 local panel = new("Frame", {
 Position = UDim2.fromOffset(16, topBarHeight() + 44),
 Size = UDim2.fromOffset(230, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 Active = true,
 Parent = self.Gui,
 }, {
 corner(9),
 outline(0.88),
 padding(10, 10, 12, 12),
 new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
 })
 local head = new("Frame", {
 Size = UDim2.new(1, 0, 0, 18),
 BackgroundTransparency = 1,
 LayoutOrder = 0,
 Parent = panel,
 })
 bindAccent(icon("keyboard", 14, Theme.Accent, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.fromScale(0, 0.5),
 Parent = head,
 }), "ImageColor3")
 new("TextLabel", {
 Position = UDim2.fromOffset(22, 0),
 Size = UDim2.new(1, -22, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = "Keybinds",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = head,
 })
 makeDraggable(panel, panel, self._conns)
 self._keybindList = panel
 end
 self:_refreshKeybinds()
end

function Window:_refreshKeybinds()
 local panel = self._keybindList
 if not panel then return end
 for _, c in ipairs(panel:GetChildren()) do
 if c.Name == "Entry" then c:Destroy() end
 end
 local count = 0
 for _, t in ipairs(self._bindables) do
 if t.Key then
 count += 1
 local entry = new("Frame", {
 Name = "Entry",
 Size = UDim2.new(1, 0, 0, 20),
 BackgroundTransparency = 1,
 LayoutOrder = count,
 Parent = panel,
 })
 local dot = new("Frame", {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 3, 0.5, 0),
 Size = UDim2.fromOffset(6, 6),
 BackgroundColor3 = t.Value and Theme.Accent or Theme.Stroke,
 BorderSizePixel = 0,
 Parent = entry,
 }, { corner("full") })
 if t.Value then bindAccent(dot, "BackgroundColor3") end
 new("TextLabel", {
 Position = UDim2.fromOffset(16, 0),
 Size = UDim2.new(1, -70, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = t.Name or "",
 TextColor3 = t.Value and Theme.Text or Theme.Muted,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = entry,
 })
 new("TextLabel", {
 AnchorPoint = Vector2.new(1, 0),
 Size = UDim2.new(0, 50, 1, 0),
 Position = UDim2.fromScale(1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = "[" .. t.Key.Name .. "]",
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Right,
 Parent = entry,
 })
 end
 end
 panel.Visible = self._keybindListOn and count > 0
end

-- ============================================================================
-- CONFIGS
-- ============================================================================
-- Saves every element created with a Flag to /.json.
-- Toggle keybinds are saved alongside their toggle. ExportConfig and
-- ImportConfig move the same data through a string (clipboard sharing).
-- ============================================================================
local function canUseFiles()
 return writefile and readfile and isfile and isfolder and makefolder
end

-- makefolder for a nested path ("Prism/12345"), one level at a time.
local function ensureFolder(path)
 local built = ""
 for part in string.gmatch(path, "[^/]+") do
 built = built == "" and part or (built .. "/" .. part)
 if not isfolder(built) then makefolder(built) end
 end
end

local function serializeFlags()
 local data = {}
 for flag, el in pairs(Prism.Flags) do
 local v = el.Value
 if typeof(v) == "EnumItem" then
 v = { __enum = v.Name }
 elseif typeof(v) == "Color3" then
 v = { __color = v:ToHex() }
 end
 data[flag] = v
 if el.Key then data[flag .. "::key"] = { el.Key.Name, el.Mode } end
 end
 return data
end

local function applyFlags(data)
 -- The theme goes first: it sets an accent, which a saved custom accent
 -- colour should then be able to override.
 if data.Prism_Theme and Prism.Flags.Prism_Theme then
 Prism.Flags.Prism_Theme:Set(data.Prism_Theme)
 end
 for flag, v in pairs(data) do
 if flag == "Prism_Theme" then continue end
 local base, isKey = string.match(flag, "^(.-)::(key)$")
 local el = Prism.Flags[base or flag]
 if el then
 if isKey then
 if el.SetKey then el:SetKey(v[1], v[2]) end
 elseif el.Set then
 if typeof(v) == "table" and v.__enum then v = Enum.KeyCode[v.__enum] end
 if typeof(v) == "table" and v.__color then v = Color3.fromHex(v.__color) end
 el:Set(v)
 end
 end
 end
end

function Window:SaveConfig(name)
 if not canUseFiles() then return false end
 ensureFolder(self.ConfigFolder)
 writefile(self.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(serializeFlags()))
 self.ActiveConfig = name
 return true
end

function Window:LoadConfig(name)
 if not canUseFiles() then return false end
 local path = self.ConfigFolder .. "/" .. name .. ".json"
 if not isfile(path) then return false end
 local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(path))
 if not ok then return false end
 applyFlags(data)
 self.ActiveConfig = name
 task.defer(function() self:_reportKeyConflicts() end)
 return true
end

function Window:ExportConfig()
 return HttpService:JSONEncode(serializeFlags())
end

function Window:ImportConfig(text)
 local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
 if not ok or typeof(data) ~= "table" then return false end
 applyFlags(data)
 return true
end

function Window:DeleteConfig(name)
 local path = self.ConfigFolder .. "/" .. name .. ".json"
 if delfile and isfile and isfile(path) then delfile(path) return true end
 return false
end

-- Profiles: a config bound to this place or this account loads on start,
-- ahead of the plain autoload. Place wins over account. Stored in
-- /profiles.json as { Place = { [placeId] = name },
-- Account = { [userId] = name } }.
local PROFILE_SCOPES = { Place = true, Account = true }

local function profileId(scope)
 return scope == "Place" and tostring(game.PlaceId) or tostring(LocalPlayer.UserId)
end

function Window:_readProfiles()
 local data = { Place = {}, Account = {} }
 local path = self.ConfigFolder .. "/profiles.json"
 if canUseFiles() and isfile(path) then
 local ok, saved = pcall(HttpService.JSONDecode, HttpService, readfile(path))
 if ok and typeof(saved) == "table" then
 data.Place = typeof(saved.Place) == "table" and saved.Place or {}
 data.Account = typeof(saved.Account) == "table" and saved.Account or {}
 end
 end
 return data
end

-- Window:SetProfile("Place" | "Account", name) -- name nil unbinds
function Window:SetProfile(scope, name)
 if not (canUseFiles() and PROFILE_SCOPES[scope]) then return false end
 local data = self:_readProfiles()
 data[scope][profileId(scope)] = name
 ensureFolder(self.ConfigFolder)
 writefile(self.ConfigFolder .. "/profiles.json", HttpService:JSONEncode(data))
 return true
end

function Window:GetProfile(scope)
 if not PROFILE_SCOPES[scope] then return nil end
 return self:_readProfiles()[scope][profileId(scope)]
end

function Window:ListConfigs()
 local out = {}
 if not (listfiles and isfolder and isfolder(self.ConfigFolder)) then return out end
 for _, file in ipairs(listfiles(self.ConfigFolder)) do
 local name = string.match(file, "([^/\\]+)%.json$")
 if name then table.insert(out, name) end
 end
 table.sort(out)
 return out
end

-- ============================================================================
-- SETTINGS TAB
-- ============================================================================
-- Window:SettingsTab() adds a ready-made Settings tab. Call it after your
-- own tabs.
--
-- Appearance theme preset, accent, UI scale, opacity, background blur
-- Behaviour menu key, reduce motion, shine, tooltips, sounds
-- Overlay watermark (+ readouts), keybind list, notification corner
-- Configs save / load / delete, export / import, autoload
-- Info version, executor, game, players, FPS, ping, session time
-- Session rejoin, copy server id, unload
-- ============================================================================

function Window:SettingsTab(opts)
 opts = opts or {}
 local tab = self:Tab({
 Name = opts.Name or "Settings",
 Icon = opts.Icon or "settings",
 Description = "Interface, configs and session",
 })

 -- Appearance ------------------------------------------------------------
 local look = tab:Section({ Name = "Appearance", Icon = "palette", Side = "Left" })
 local themeNames = {}
 for _, t in ipairs(Prism.Themes) do table.insert(themeNames, t.Name) end
 local accentPicker
 look:Dropdown({
 Name = "Theme",
 Description = "Full colour themes: backgrounds, surfaces, text and accent.",
 Options = themeNames,
 Default = Prism.CurrentTheme,
 Flag = "Prism_Theme",
 Callback = function(name)
 if Prism:SetTheme(name) and accentPicker then accentPicker:Set(Theme.Accent, true) end
 end,
 })
 local fontNames = {}
 for _, f in ipairs(Prism.FontFamilies) do table.insert(fontNames, f[1]) end
 look:Dropdown({
 Name = "Font",
 Description = "Changes every label in the UI.",
 Options = fontNames,
 Default = Prism.CurrentFont,
 Flag = "Prism_Font",
 Callback = function(name) Prism:SetFont(name) end,
 })
 accentPicker = look:ColorPicker({
 Name = "Accent colour",
 Description = "Any colour you like. Recolours every highlight.",
 Default = Theme.Accent,
 Flag = "Prism_Accent",
 Callback = function(color) Prism:SetAccent(color) end,
 })
 look:Slider({
 Name = "UI scale",
 Description = "Size of the window. Capped to fit your screen.",
 Min = 70, Max = 150, Increment = 5, Suffix = "%",
 Default = math.floor(self.BaseScale * 100 / 5 + 0.5) * 5,
 Flag = "Prism_Scale",
 Callback = function(v) self:SetScale(v / 100) end,
 })
 look:Slider({
 Name = "Window opacity",
 Description = "Lower lets the game show through. Try it with blur.",
 Min = 50, Max = 100, Increment = 5, Default = 100, Suffix = "%",
 Flag = "Prism_Opacity",
 Callback = function(v) self:SetOpacity(v / 100) end,
 })
 look:Toggle({
 Name = "Blur game behind menu",
 HideFromList = true,
 Description = "Frosted-glass look while the menu is open.",
 Flag = "Prism_Blur",
 Callback = function(on) self:SetBlur(on) end,
 })
 look:Segmented({
 Name = "Window border",
 Description = "Accent: two soft lights orbit the window edge.",
 Options = { "Subtle", "Glass", "Accent", "None" },
 Default = self.BorderStyle or "Subtle",
 Flag = "Prism_Border",
 Callback = function(style) self:SetBorderStyle(style) end,
 })

 -- Behaviour -------------------------------------------------------------
 local behave = tab:Section({ Name = "Behaviour", Icon = "sliders", Side = "Left" })
 behave:Keybind({
 Name = "Menu key",
 Description = "Shows and hides the window.",
 Default = self.ToggleKey,
 Flag = "Prism_MenuKey",
 ChangedCallback = function(key) if key then self:SetToggleKey(key) end end,
 })
 behave:Toggle({
 Name = "Compact sidebar",
 HideFromList = true,
 Description = "Icons only. Hover a tab to see its name.",
 Flag = "Prism_Compact",
 Callback = function(on) self:SetCompact(on) end,
 })
 behave:Toggle({
 Name = "Menu shine",
 HideFromList = true,
 Description = "Light sweep across active controls.",
 Default = true,
 Flag = "Prism_Shine",
 Callback = function(on) Prism.ShineEnabled = on end,
 })
 behave:Toggle({
 Name = "Reduce motion",
 HideFromList = true,
 Description = "Turns off ripples, spotlight, aurora drift and staggered animations.",
 Flag = "Prism_ReduceMotion",
 Callback = function(on) Prism.ReduceMotion = on end,
 })
 behave:Toggle({
 Name = "Tooltips",
 HideFromList = true,
 Description = "Shows hints like this one.",
 Default = true,
 Flag = "Prism_Tooltips",
 Callback = function(on) Prism.Tooltips = on end,
 })
 behave:Toggle({
 Name = "UI sounds",
 HideFromList = true,
 Description = "Soft clicks on toggles, buttons and notifications.",
 Flag = "Prism_Sounds",
 Callback = function(on) Prism.Sounds = on end,
 })
 behave:Slider({
 Name = "Sound volume",
 Min = 0, Max = 100, Increment = 5, Default = 50, Suffix = "%",
 Flag = "Prism_SoundVolume",
 Callback = function(v) Prism.SoundVolume = v / 100 end,
 })

 -- Overlay ---------------------------------------------------------------
 local overlay = tab:Section({ Name = "Overlay", Icon = "eye", Side = "Left" })
 overlay:Toggle({
 Name = "Watermark",
 HideFromList = true,
 Description = "Name and live stats in the corner. Drag to move.",
 Flag = "Prism_Watermark",
 Callback = function(on) self:SetWatermark(on) end,
 })
 overlay:Dropdown({
 Name = "Watermark shows",
 Multi = true,
 Options = { "FPS", "Ping", "Players", "Time" },
 Default = { "FPS", "Ping", "Time" },
 Flag = "Prism_WatermarkItems",
 Callback = function(list) self:SetWatermarkItems(list) end,
 })
 overlay:Toggle({
 Name = "Keybind list",
 HideFromList = true,
 Description = "Toggles you've bound to a key. Right-click a toggle to bind it.",
 Flag = "Prism_KeybindList",
 Callback = function(on) self:SetKeybindList(on) end,
 })
 overlay:Toggle({
 Name = "Active modules",
 HideFromList = true,
 Description = "Lists every feature that's on in the top-right corner.",
 Flag = "Prism_ModuleList",
 Callback = function(on) self:SetModuleList(on) end,
 })
 overlay:Segmented({
 Name = "Notifications",
 Options = { "Top", "Bottom" },
 Default = "Bottom",
 Flag = "Prism_NotifySide",
 Callback = function(v) Prism:SetNotifyPosition(v == "Top" and "TopRight" or "BottomRight") end,
 })
 overlay:Button({
 Name = "Test notification",
 Icon = "bell",
 Callback = function()
 -- Loading toast with live progress that turns into a success.
 local n = Prism:Notify({ Title = "Working", Content = "Watch this one update itself.", Type = "Loading", Progress = 0 })
 task.spawn(function()
 for i = 1, 10 do
 task.wait(0.15)
 n:SetProgress(i / 10)
 end
 n:Update({ Title = "Looking good", Content = "Hover to pause. Click to dismiss.", Type = "Success", Progress = false })
 end)
 end,
 })
 overlay:Toggle({
 Name = "Do not disturb",
 HideFromList = true,
 Description = "Hides notifications. They still go into the history.",
 Flag = "Prism_DND",
 Callback = function(on) Prism.NotifyMuted = on end,
 })
 overlay:Button({
 Name = "Clear notifications",
 Icon = "trash-2",
 Callback = function() Prism:ClearNotifications() end,
 })

 -- Configs ---------------------------------------------------------------
 local cfg = tab:Section({ Name = "Configs", Icon = "save", Side = "Right" })
 cfg:Stat({ Name = "Saving to", Value = self.ConfigFolder, Icon = "folder" })
 local syncProfiles = function() end -- set once the profile toggles exist
 local nameBox = cfg:Textbox({
 Name = "Config name",
 Placeholder = "default",
 Default = "default",
 Callback = function() syncProfiles() end,
 })
 local list = cfg:Dropdown({
 Name = "Saved configs",
 Options = self:ListConfigs(),
 Placeholder = "None saved",
 Callback = function(v)
 if v then
 nameBox:Set(v, true)
 syncProfiles()
 end
 end,
 })
 local function current()
 return (nameBox.Value ~= "" and nameBox.Value) or "default"
 end
 local function refresh() list:Refresh(self:ListConfigs()) end

 cfg:Button({
 Name = "Save config",
 Style = "Primary",
 Icon = "save",
 Callback = function()
 if self:SaveConfig(current()) then
 refresh()
 Prism:Notify({ Title = "Config saved", Content = "Saved as " .. current() .. ".", Type = "Success" })
 else
 Prism:Notify({ Title = "Can't save", Content = "Your executor doesn't support file access.", Type = "Error" })
 end
 end,
 })
 cfg:ButtonRow({
 {
 Name = "Load",
 Icon = "folder-open",
 Callback = function()
 local ok = self:LoadConfig(current())
 Prism:Notify({
 Title = ok and "Config loaded" or "Config not found",
 Content = " " .. current() .. " ",
 Type = ok and "Success" or "Warning",
 })
 end,
 },
 {
 Name = "Delete",
 Icon = "trash-2",
 Hold = 1,
 HoldText = "Hold...",
 Callback = function()
 if self:DeleteConfig(current()) then
 refresh()
 Prism:Notify({ Title = "Config deleted", Content = " " .. current() .. " ", Type = "Warning" })
 end
 end,
 },
 { Name = "Refresh", Icon = "refresh-cw", Callback = refresh },
 })
 cfg:ButtonRow({
 {
 Name = "Share code",
 Icon = "upload",
 Callback = function()
 Prism:Notify({ Title = "Uploading...", Content = "Creating a share code.", Duration = 2 })
 local code, err = self:ShareConfig()
 if code then
 if setclipboard then setclipboard(code) end
 Prism:Notify({
 Title = "Share code: " .. code,
 Content = "Copied. Friends paste it into Import code.",
 Type = "Success",
 Duration = 8,
 })
 else
 Prism:Notify({ Title = "Couldn't share", Content = err or "Upload failed.", Type = "Error" })
 end
 end,
 },
 {
 Name = "Export",
 Icon = "copy",
 Callback = function()
 if setclipboard then
 setclipboard(self:ExportConfig())
 Prism:Notify({ Title = "Config copied", Content = "Paste it anywhere to share it.", Type = "Success" })
 else
 Prism:Notify({ Title = "Can't copy", Content = "Your executor has no clipboard access.", Type = "Error" })
 end
 end,
 },
 })
 cfg:Textbox({
 Name = "Import",
 Description = "Paste an exported config and press Enter.",
 Placeholder = "Paste config...",
 ClearOnEnter = true,
 Callback = function(text)
 if text == "" then return end
 local ok = self:ImportConfig(text)
 Prism:Notify({
 Title = ok and "Config imported" or "Invalid config",
 Content = ok and "Settings applied." or "That doesn't look like a Prism config.",
 Type = ok and "Success" or "Error",
 })
 end,
 })

 cfg:Textbox({
 Name = "Import code",
 Description = "Paste a share code and press Enter.",
 Placeholder = "Share code...",
 ClearOnEnter = true,
 Callback = function(code)
 if code == "" then return end
 local ok, err = self:ImportShared(code)
 Prism:Notify({
 Title = ok and "Config imported" or "Couldn't import",
 Content = ok and "Shared settings applied." or err,
 Type = ok and "Success" or "Error",
 })
 end,
 })

 -- Autoload and profiles. The toggles show whether the config named in
 -- the box is the one that loads on start.
 local autoPath = self.ConfigFolder .. "/autoload.txt"
 local function autoloadName()
 return canUseFiles() and isfile(autoPath) and readfile(autoPath) or nil
 end
 local autoToggle = cfg:Toggle({
 Name = "Autoload this config",
 HideFromList = true,
 Description = "Loads it automatically next time.",
 Callback = function(on)
 if not canUseFiles() then return end
 ensureFolder(self.ConfigFolder)
 if on then
 writefile(autoPath, current())
 elseif delfile and isfile(autoPath) and readfile(autoPath) == current() then
 delfile(autoPath)
 end
 end,
 })
 local function profileToggle(scope, name, description)
 return cfg:Toggle({
 Name = name,
 HideFromList = true,
 Description = description,
 Callback = function(on)
 local config = current()
 if on then
 self:SetProfile(scope, config)
 elseif self:GetProfile(scope) == config then
 self:SetProfile(scope, nil)
 end
 end,
 })
 end
 local placeToggle = profileToggle("Place", "Load on this place",
 "Loads this config whenever you join this place. Beats every other autoload.")
 local accountToggle = profileToggle("Account", "Load on this account",
 "Loads this config whenever " .. LocalPlayer.Name .. " runs the script, in any place of this game.")
 syncProfiles = function()
 local name = current()
 autoToggle:Set(autoloadName() == name, true)
 placeToggle:Set(self:GetProfile("Place") == name, true)
 accountToggle:Set(self:GetProfile("Account") == name, true)
 end

 -- Auto-save. Only writes over a config loaded or saved this session, so
 -- switching it on can't overwrite a saved config with fresh defaults.
 local autoSavePath = self.ConfigFolder .. "/autosave.txt"
 local saveStat = cfg:Stat({ Name = "Auto-save", Value = "Off", Icon = "clock" })
 local lastSnapshot, warnedOverwrite
 local function snapshot() return HttpService:JSONEncode(serializeFlags()) end
 local function autoSave()
 if not (self.AutoSave and canUseFiles()) then return end
 local snap = snapshot()
 if snap == lastSnapshot then return end
 local target = self.ActiveConfig
 if not target then
 local name = current()
 if isfile(self.ConfigFolder .. "/" .. name .. ".json") then
 if not warnedOverwrite then
 warnedOverwrite = true
 Prism:Notify({
 Title = "Auto-save paused",
 Content = " " .. name .. " already exists and isn't loaded. Load it, or overwrite it with your current settings.",
 Type = "Warning",
 Duration = 12,
 Buttons = {
 { Name = "Load it", Primary = true, Callback = function() self:LoadConfig(name) end },
 { Name = "Overwrite", Callback = function() self.ActiveConfig = name end },
 },
 })
 end
 return
 end
 target = name
 end
 lastSnapshot = snap
 local isNew = not isfile(self.ConfigFolder .. "/" .. target .. ".json")
 if self:SaveConfig(target) then
 saveStat:Set(target .. " · " .. os.date("%H:%M:%S"))
 if isNew then refresh() end
 end
 end
 self._autoSaveFinal = autoSave
 local autoSaveDefault = canUseFiles() and isfile(autoSavePath) or false
 self.AutoSave = autoSaveDefault
 if autoSaveDefault then saveStat:Set("Waiting for changes") end
 cfg:Toggle({
 Name = "Auto-save",
 HideFromList = true,
 Description = "Saves your settings a couple of seconds after you change them, and on unload.",
 Default = autoSaveDefault,
 Callback = function(on)
 self.AutoSave = on
 warnedOverwrite = false
 saveStat:Set(on and "Waiting for changes" or "Off")
 if not canUseFiles() then return end
 ensureFolder(self.ConfigFolder)
 if on then
 writefile(autoSavePath, "1")
 elseif delfile and isfile(autoSavePath) then
 delfile(autoSavePath)
 end
 end,
 })
 task.spawn(function()
 task.wait(3) -- let the startup config apply first; that's the baseline
 lastSnapshot = snapshot()
 while self.Gui.Parent and not self._unloaded do
 pcall(autoSave)
 task.wait(2)
 end
 end)

 -- Info ------------------------------------------------------------------
 local info = tab:Section({ Name = "Info", Icon = "info", Side = "Right" })
 info:Stat({ Name = "Version", Value = "v" .. Prism.Version, Icon = "gem" })
 local executor = "Unknown"
 pcall(function() executor = identifyexecutor and (identifyexecutor()) or executor end)
 info:Stat({ Name = "Executor", Value = executor, Icon = "terminal" })
 local gameStat = info:Stat({ Name = "Game", Value = "...", Icon = "gamepad-2" })
 task.spawn(function()
 local ok, product = pcall(function()
 return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
 end)
 gameStat:Set(ok and product and product.Name or tostring(game.PlaceId))
 end)
 local playersStat = info:Stat({ Name = "Players", Icon = "users" })
 local perfStat = info:Stat({ Name = "Performance", Icon = "activity" })
 local sessionStat = info:Stat({ Name = "Session", Icon = "clock" })
 local started = os.clock()
 task.spawn(function()
 while self.Gui.Parent do
 playersStat:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
 perfStat:Set(stats.FPS .. " fps · " .. stats.Ping .. " ms")
 local t = math.floor(os.clock() - started)
 sessionStat:Set(string.format("%02d:%02d:%02d", t // 3600, t // 60 % 60, t % 60))
 task.wait(1)
 end
 end)

 -- Session ---------------------------------------------------------------
 local session = tab:Section({ Name = "Session", Icon = "power", Side = "Right" })
 session:ButtonRow({
 {
 Name = "Rejoin",
 Icon = "refresh-cw",
 Callback = function()
 local tp = game:GetService("TeleportService")
 if #Players:GetPlayers() <= 1 then
 tp:Teleport(game.PlaceId, LocalPlayer)
 else
 tp:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
 end
 end,
 },
 {
 Name = "Copy server",
 Icon = "copy",
 Callback = function()
 if setclipboard then
 setclipboard(game.JobId)
 Prism:Notify({ Title = "Server id copied", Content = game.JobId, Type = "Success" })
 end
 end,
 },
 })
 session:Button({
 Name = "Unload",
 Description = "Turns every feature off and removes the UI.",
 Icon = "power",
 Hold = 1.2,
 HoldText = "Hold to unload...",
 Callback = function() self:Unload() end,
 })

 -- Startup config: this place's profile, then this account's, then the
 -- plain autoload.
 local startName, reason = self:GetProfile("Place"), "bound to this place"
 if not startName then startName, reason = self:GetProfile("Account"), "bound to your account" end
 if not startName then startName, reason = autoloadName(), "autoload" end
 task.defer(function()
 if startName then
 nameBox:Set(startName, true)
 if self:LoadConfig(startName) then
 Prism:Notify({ Title = "Config loaded", Content = " " .. startName .. " · " .. reason, Type = "Success" })
 end
 end
 syncProfiles()
 end)
 return tab
end

-- ============================================================================
-- UTILITY TAB
-- ============================================================================
-- Window:UtilityTab() adds a ready-made Utility tab:
--
-- Server live server info, rejoin, server hop, join by id, copy
-- join link / script
-- Performance FPS cap, low graphics, 3D rendering off, mute game
-- Player anti-AFK, auto-rejoin on disconnect
--
-- Everything is flagged (Prism_Util_*), so it saves with configs, and the
-- toggles switch off (restoring the game) on unload.
-- ============================================================================
local function httpGet(url)
 local ok, body = pcall(function() return game:HttpGet(url) end)
 if ok and type(body) == "string" then return body end
 local req = (syn and syn.request) or (http and http.request) or http_request or request
 if not req then return nil end
 local ok2, res = pcall(req, { Url = url, Method = "GET" })
 return ok2 and res and res.Body or nil
end

-- Public servers of this place, minus this one. sort: "Asc" | "Desc".
local function fetchServers(sort)
 local url = string.format(
 "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true",
 game.PlaceId, sort)
 local body = httpGet(url)
 if not body then return nil, "Your executor can't make web requests." end
 local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
 if not ok or typeof(data) ~= "table" or typeof(data.data) ~= "table" then
 return nil, "Roblox didn't return a server list. Try again in a bit."
 end
 local out = {}
 for _, server in ipairs(data.data) do
 if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 0) then
 table.insert(out, server)
 end
 end
 return out
end

function Window:UtilityTab(opts)
 opts = opts or {}
 local TeleportService = svc("TeleportService")
 local GuiService = svc("GuiService")
 local tab = self:Tab({
 Name = opts.Name or "Utility",
 Icon = opts.Icon or "wrench",
 Description = "Server, performance and session tools",
 })

 -- Server ----------------------------------------------------------------
 local server = tab:Section({ Name = "Server", Icon = "server", Side = "Left" })
 server:Stat({
 Name = "Players",
 Icon = "users",
 Bind = function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end,
 })
 server:Stat({
 Name = "Server age",
 Icon = "clock",
 BindInterval = 1,
 Bind = function()
 local t = math.floor(workspace.DistributedGameTime)
 return string.format("%02d:%02d:%02d", t // 3600, t // 60 % 60, t % 60)
 end,
 })
 server:Stat({
 Name = "Ping",
 Icon = "activity",
 BindInterval = 0.5,
 Bind = function() return stats.Ping .. " ms" end,
 })

 local function rejoin()
 Prism:Notify({ Title = "Rejoining", Content = "Hang on...", Type = "Loading" })
 if #Players:GetPlayers() <= 1 then
 TeleportService:Teleport(game.PlaceId, LocalPlayer)
 else
 TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
 end
 end

 -- Server hop: tries servers in order until a teleport goes through.
 local hopMode = "Smallest"
 local hopping = false
 local function hop()
 if hopping then return end
 hopping = true
 local toast = Prism:Notify({ Title = "Server hop", Content = "Finding a server...", Type = "Loading" })
 task.spawn(function()
 local servers, err = fetchServers(hopMode == "Largest" and "Desc" or "Asc")
 if not servers or #servers == 0 then
 hopping = false
 toast:Update({ Title = "Server hop failed", Content = err or "No other servers with space.", Type = "Error" })
 return
 end
 if hopMode == "Random" then
 for i = #servers, 2, -1 do
 local j = math.random(1, i)
 servers[i], servers[j] = servers[j], servers[i]
 end
 end
 for i = 1, math.min(#servers, 5) do
 local s = servers[i]
 toast:Update({ Content = string.format("Joining a server with %d / %d players...", s.playing or 0, s.maxPlayers or 0) })
 local failed = false
 local conn = TeleportService.TeleportInitFailed:Connect(function(player)
 if player == LocalPlayer then failed = true end
 end)
 pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, s.id, LocalPlayer)
 local waited = 0
 while not failed and waited < 8 do
 waited += task.wait(0.25)
 end
 conn:Disconnect()
 if not failed then return end -- still here after 8s without a failure: let it finish
 end
 hopping = false
 toast:Update({ Title = "Server hop failed", Content = "Every server refused the teleport.", Type = "Error" })
 end)
 end

 server:ButtonRow({
 { Name = "Rejoin", Icon = "refresh-cw", Callback = rejoin },
 { Name = "Server hop", Icon = "shuffle", Callback = hop },
 })
 server:Segmented({
 Name = "Hop to",
 Description = "Which server Server hop picks.",
 Options = { "Smallest", "Random", "Largest" },
 Default = "Smallest",
 Flag = "Prism_Util_HopMode",
 Callback = function(v) hopMode = v end,
 })
 server:Textbox({
 Name = "Join server",
 Description = "Paste a server id (JobId) and press Enter.",
 Placeholder = "JobId...",
 ClearOnEnter = true,
 Callback = function(id)
 id = string.gsub(id, "%s", "")
 if id == "" then return end
 Prism:Notify({ Title = "Joining server", Content = id, Type = "Loading" })
 TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
 end,
 })
 local function copy(text, what)
 if setclipboard then
 setclipboard(text)
 Prism:Notify({ Title = what .. " copied", Content = text, Type = "Success" })
 else
 Prism:Notify({ Title = "Can't copy", Content = "Your executor has no clipboard access.", Type = "Error" })
 end
 end
 server:ButtonRow({
 { Name = "Copy id", Icon = "hash", Callback = function() copy(game.JobId, "Server id") end },
 {
 Name = "Join link",
 Icon = "link",
 Callback = function()
 copy(string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", game.PlaceId, game.JobId), "Join link")
 end,
 },
 {
 Name = "Join script",
 Icon = "copy",
 Callback = function()
 copy(string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")', game.PlaceId, game.JobId), "Join script")
 end,
 },
 })

 -- Performance -----------------------------------------------------------
 local perf = tab:Section({ Name = "Performance", Icon = "gauge", Side = "Right" })
 perf:Stat({
 Name = "FPS",
 Icon = "monitor",
 BindInterval = 0.5,
 Bind = function() return tostring(stats.FPS) end,
 })
 if setfpscap then
 perf:Slider({
 Name = "FPS cap",
 Description = "0 removes the cap.",
 Min = 0, Max = 360, Increment = 5, Suffix = " fps",
 Flag = "Prism_Util_FPSCap",
 Callback = function(v) pcall(setfpscap, v) end,
 })
 end

 local lowGfx = {}
 perf:Toggle({
 Name = "Low graphics",
 HideFromList = true,
 Description = "Lowest render quality, no shadows or post effects.",
 Flag = "Prism_Util_LowGfx",
 Callback = function(on)
 if on then
 lowGfx.Shadows = Lighting.GlobalShadows
 Lighting.GlobalShadows = false
 pcall(function()
 lowGfx.Quality = settings().Rendering.QualityLevel
 settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
 end)
 lowGfx.Effects = {}
 for _, fx in ipairs(Lighting:GetChildren()) do
 if fx:IsA("PostEffect") and fx.Enabled then
 fx.Enabled = false
 table.insert(lowGfx.Effects, fx)
 end
 end
 elseif lowGfx.Effects then
 Lighting.GlobalShadows = lowGfx.Shadows
 pcall(function() settings().Rendering.QualityLevel = lowGfx.Quality end)
 for _, fx in ipairs(lowGfx.Effects) do
 if fx.Parent then fx.Enabled = true end
 end
 lowGfx.Effects = nil
 end
 end,
 })
 perf:Toggle({
 Name = "Disable 3D rendering",
 HideFromList = true,
 Description = "Blank world, UI only. Big CPU and GPU savings while AFK.",
 Flag = "Prism_Util_No3D",
 Callback = function(on) pcall(RunService.Set3dRenderingEnabled, RunService, not on) end,
 })
 local volume
 perf:Toggle({
 Name = "Mute game",
 HideFromList = true,
 Description = "Sets the master volume to 0. Restored when turned off.",
 Flag = "Prism_Util_Mute",
 Callback = function(on)
 pcall(function()
 local gs = UserSettings():GetService("UserGameSettings")
 if on then
 volume = gs.MasterVolume
 gs.MasterVolume = 0
 elseif volume then
 gs.MasterVolume = volume
 end
 end)
 end,
 })

 -- Player ----------------------------------------------------------------
 local player = tab:Section({ Name = "Player", Icon = "user", Side = "Left" })
 local afkConn
 player:Toggle({
 Name = "Anti-AFK",
 HideFromList = true,
 Description = "Stops the 20-minute idle kick.",
 Flag = "Prism_Util_AntiAFK",
 Callback = function(on)
 if afkConn then afkConn:Disconnect() afkConn = nil end
 if not on then return end
 local vu = svc("VirtualUser")
 afkConn = LocalPlayer.Idled:Connect(function()
 pcall(function()
 vu:CaptureController()
 vu:ClickButton2(Vector2.new())
 end)
 end)
 table.insert(self._conns, afkConn)
 end,
 })

 local autoRejoin = false
 player:Toggle({
 Name = "Auto-rejoin on disconnect",
 HideFromList = true,
 Description = "Rejoins by itself after a kick or lost connection.",
 Flag = "Prism_Util_AutoRejoin",
 Callback = function(on) autoRejoin = on end,
 })
 local rejoining = false
 local function onDisconnect()
 if not autoRejoin or rejoining or self._unloaded then return end
 rejoining = true
 task.wait(2)
 while not self._unloaded do
 pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
 task.wait(10)
 end
 end
 table.insert(self._conns, GuiService.ErrorMessageChanged:Connect(function()
 if GuiService:GetErrorMessage() ~= "" then task.spawn(onDisconnect) end
 end))
 pcall(function()
 local overlay = CoreGui:FindFirstChild("RobloxPromptGui"):FindFirstChild("promptOverlay")
 table.insert(self._conns, overlay.ChildAdded:Connect(function(child)
 if child.Name == "ErrorPrompt" then task.spawn(onDisconnect) end
 end))
 end)

 return tab
end

-- ============================================================================
-- UNLOAD
-- ============================================================================
-- Window:OnUnload(fn) registers cleanup. Window:Unload() turns every flagged
-- toggle off (firing its callback), runs the hooks, then removes the UI.
-- ============================================================================
function Window:OnUnload(fn)
 table.insert(self._unloadHooks, fn)
end

function Window:Unload()
 if self._unloaded then return end
 self._unloaded = true
 -- Auto-save gets the real state, before everything is switched off.
 if self._autoSaveFinal then pcall(self._autoSaveFinal) end
 for _, el in pairs(Prism.Flags) do
 if el.Value == true and el.Set then pcall(el.Set, el, false) end
 end
 for _, fn in ipairs(self._unloadHooks) do pcall(fn) end
 self:Destroy()
 if notifyGui then notifyGui:Destroy() end
 table.clear(Prism.Flags)
end

function Window:Destroy()
 tween(self.Main, 0.25, { GroupTransparency = 1 })
 tween(self.Shadow, 0.25, { ImageTransparency = 1 })
 tween(self.Underglow, 0.25, { ImageTransparency = 1 })
 tween(self.RootScale, 0.25, { Scale = self.BaseScale * 0.9 }).Completed:Wait()
 for _, c in ipairs(self._conns) do c:Disconnect() end
 self.Gui:Destroy()
 for _, name in ipairs({ "PrismBlur", "PrismMenuBlur" }) do
 local blur = Lighting:FindFirstChild(name)
 if blur then blur:Destroy() end
 end
end

-- ============================================================================
-- BUILT-IN COMMANDS
-- ============================================================================
function Window:_addDefaultCommands()
 self:AddCommand({ Name = "Hide menu", Icon = "eye-off", Description = "Minimise to the pill", Callback = function() self:Minimize() end })
 self:AddCommand({
 Name = "Rejoin server",
 Icon = "refresh-cw",
 Callback = function()
 local tp = game:GetService("TeleportService")
 if #Players:GetPlayers() <= 1 then
 tp:Teleport(game.PlaceId, LocalPlayer)
 else
 tp:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
 end
 end,
 })
 self:AddCommand({
 Name = "Copy server id",
 Icon = "copy",
 Callback = function()
 if setclipboard then
 setclipboard(game.JobId)
 Prism:Notify({ Title = "Server id copied", Content = game.JobId, Type = "Success" })
 end
 end,
 })
 self:AddCommand({
 Name = "Unload",
 Icon = "power",
 Description = "Turn everything off and remove the UI",
 Callback = function()
 self:Dialog({
 Title = "Unload " .. self.Title .. "?",
 Content = "Turns every feature off and removes the UI.",
 Icon = "power",
 Buttons = {
 { Title = "Cancel" },
 { Title = "Unload", Primary = true, Callback = function() self:Unload() end },
 },
 })
 end,
 })
 for _, t in ipairs(Prism.Themes or {}) do
 self:AddCommand({
 Name = "Theme: " .. t.Name,
 Icon = "palette",
 Description = "Switch colour theme",
 Callback = function()
 local themeFlag = Prism.Flags.Prism_Theme
 if themeFlag then themeFlag:Set(t.Name) else Prism:SetTheme(t) end
 end,
 })
 end
end

-- ============================================================================
-- ACTIVE MODULES LIST
-- ============================================================================
-- Vape-style list in the top-right corner of every toggle that's on,
-- longest name first, each line tinted with the accent gradient. Toggles
-- made with HideFromList = true (all of Prism's own settings) are skipped.
-- Window:SetModuleList(true | false)
-- ============================================================================
function Window:SetModuleList(on)
 self._modulesOn = on
 if on and not self._moduleList then
 local inset = game:GetService("GuiService"):GetGuiInset().Y
 self._moduleList = new("Frame", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -12, 0, inset + 10),
 Size = UDim2.fromOffset(320, 0),
 AutomaticSize = Enum.AutomaticSize.Y,
 BackgroundTransparency = 1,
 Parent = self.Gui,
 }, {
 new("UIListLayout", {
 HorizontalAlignment = Enum.HorizontalAlignment.Right,
 Padding = UDim.new(0, 1),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 self._moduleRows = {}
 end
 if self._moduleList then self._moduleList.Visible = on end
 self:_refreshModules()
end

function Window:_refreshModules()
 local list = self._moduleList
 if not list then return end
 local rows = self._moduleRows

 for _, t in ipairs(self._bindables) do
 local show = t.Value and not t.HideFromList and t.Name ~= nil
 local row = rows[t]
 if show and not row then
 row = new("Frame", {
 Size = UDim2.fromOffset(0, 20),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundColor3 = Theme.Surface,
 BackgroundTransparency = 0.15,
 BorderSizePixel = 0,
 ClipsDescendants = true,
 LayoutOrder = -#t.Name,
 Parent = list,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 7),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 padding(0, 0, 8, 0),
 })
 local label = new("TextLabel", {
 Size = UDim2.fromOffset(0, 20),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = t.Name,
 TextColor3 = WHITE,
 TextSize = 12,
 TextTransparency = 1,
 LayoutOrder = 1,
 Parent = row,
 })
 accentGradient(label)
 local bar = new("Frame", {
 Size = UDim2.fromOffset(2, 20),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 LayoutOrder = 2,
 Parent = row,
 })
 accentGradient(bar, 90)
 rows[t] = row
 tween(label, 0.25, { TextTransparency = 0 })
 elseif not show and row then
 rows[t] = nil
 local label = row:FindFirstChildOfClass("TextLabel")
 if label then tween(label, 0.2, { TextTransparency = 1 }) end
 tween(row, 0.2, { BackgroundTransparency = 1 }).Completed:Connect(function() row:Destroy() end)
 end
 end
end

-- ============================================================================
-- ESP PREVIEW
-- ============================================================================
-- A panel with a rotating copy of your character and ESP drawn over it
-- from your own flags, so people can see what their settings look like.
-- The box is projected from the model's real 3D bounds every frame, so it
-- moves with the model like real ESP.
--
-- Docked sits to the right of the window, shown while its tab is open
-- Detached floats anywhere (drag the header) and stays up even when
-- the menu is hidden
--
-- Header buttons: reset view, lock / unlock spin, detach / dock, close.
-- Drag the stage left and right to turn the model by hand.
--
-- Window:ESPPreview{
-- Tab = VisualsTab, -- docked: only shown while this tab is open
-- Section = SomeSection, -- adds an "ESP preview" toggle there
-- Flags = { -- flag names (or functions returning a value)
-- Box = "EspBox", BoxColor = "EspBoxColor", BoxStyle = "EspBoxStyle",
-- Name = "EspName", NameColor = "EspNameColor",
-- Health = "EspHealth", Distance = "EspDistance",
-- Tracer = "EspTracer", TracerColor = "EspTracerColor",
-- BoxFill = "EspFill", Skeleton = "EspSkel", SkeletonColor = "EspSkelColor",
-- Chakra = "EspChakra", Blood = "EspBlood", -- right-side / bottom bars
-- BarWidth = "EspBarWidth", -- bar thickness in px (default 3)
-- -- Lines: a function returning { { Text = "...", Color = Color3 }, ... },
-- -- drawn as a stack above the head (bottom line first). When given,
-- -- it replaces the plain name label, so a script can preview its
-- -- own info lines exactly as its ESP draws them.
-- Lines = function() return { ... } end,
-- },
-- Defaults = { Box = true, ... }, -- for features without a flag
-- Width = 210, Height = nil, -- height defaults to the window's
-- } -> Preview:SetVisible(bool), :SetDetached(bool), :ResetView(),
-- :SetSpinning(bool), :Rebuild(), :Destroy()
-- ============================================================================
function Window:ESPPreview(opts)
 opts = opts or {}
 local flags = opts.Flags or {}
 local defaults = opts.Defaults or {}
 local W = opts.Width or 210
 local HEADER = 30

 local function read(name)
 local key = flags[name]
 if typeof(key) == "function" then return key() end
 if key then
 local el = Prism.Flags[key]
 if el then return el.Value end
 end
 return defaults[name]
 end

 local dockedSize = opts.Height and UDim2.fromOffset(W, opts.Height) or UDim2.new(0, W, 1, 0)
 local panel = new("CanvasGroup", {
 Position = UDim2.new(1, 12, 0, 0),
 Size = dockedSize,
 BackgroundColor3 = Theme.Background,
 BorderSizePixel = 0,
 Parent = self.Root,
 }, { corner(10), outline(0.88) })
 local panelScale = new("UIScale", { Parent = panel })
 table.insert(self._attached, panel)

 -- Header ----------------------------------------------------------------
 local header = new("Frame", {
 Size = UDim2.new(1, 0, 0, HEADER),
 BackgroundColor3 = Theme.Surface,
 BorderSizePixel = 0,
 Parent = panel,
 })
 bindAccent(icon("eye", 13, Theme.Accent, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 10, 0.5, 0),
 Parent = header,
 }), "ImageColor3")
 new("TextLabel", {
 Position = UDim2.fromOffset(30, 0),
 Size = UDim2.new(1, -130, 1, 0),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = opts.Name or "ESP Preview",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = header,
 })
 new("Frame", {
 Position = UDim2.fromOffset(0, HEADER - 1),
 Size = UDim2.new(1, 0, 0, 1),
 BackgroundColor3 = Theme.Outline,
 BackgroundTransparency = Theme.OutlineTransparency,
 BorderSizePixel = 0,
 Parent = header,
 })

 -- Header buttons, laid out from the right.
 local function headerButton(iconName, slot, tip, onClick)
 local b = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0.5),
 Position = UDim2.new(1, -6 - (slot - 1) * 24, 0.5, 0),
 Size = UDim2.fromOffset(22, 22),
 BackgroundColor3 = Theme.ElementHover,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 Parent = header,
 }, { corner(5) })
 local img = icon(iconName, 12, Theme.Muted, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Parent = b,
 })
 b.MouseEnter:Connect(function()
 tween(b, 0.12, { BackgroundTransparency = 0 })
 self:_showTooltip(typeof(tip) == "function" and tip() or tip)
 end)
 b.MouseLeave:Connect(function()
 tween(b, 0.12, { BackgroundTransparency = 1 })
 self:_hideTooltip()
 end)
 b.MouseButton1Click:Connect(function()
 playSound("Click", 1.1)
 onClick()
 end)
 return b, img
 end

 -- Stage -----------------------------------------------------------------
 local stage = new("Frame", {
 Position = UDim2.fromOffset(0, HEADER),
 Size = UDim2.new(1, 0, 1, -HEADER),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = panel,
 })
 local floor = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.9),
 Size = UDim2.fromOffset(130, 22),
 BackgroundTransparency = 0.9,
 BorderSizePixel = 0,
 Parent = stage,
 }, { corner("full") })
 bindAccent(floor, "BackgroundColor3")

 local viewport = new("ViewportFrame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Ambient = Color3.fromRGB(170, 170, 185),
 LightColor = Color3.fromRGB(255, 255, 255),
 LightDirection = Vector3.new(-1, -1, -1),
 Parent = stage,
 })
 local camera = Instance.new("Camera")
 camera.FieldOfView = 40
 camera.Parent = viewport
 viewport.CurrentCamera = camera

 local model
 local function buildModel()
 if model then model:Destroy() end
 local char = LocalPlayer.Character
 local ok, clone = pcall(function()
 local was = char.Archivable
 char.Archivable = true
 local c = char:Clone()
 char.Archivable = was
 return c
 end)
 if not ok or not clone then
 -- Fallback: a simple block figure.
 clone = Instance.new("Model")
 local function part(size, pos)
 local p = Instance.new("Part")
 p.Size, p.CFrame, p.Color = size, CFrame.new(pos), Color3.fromRGB(150, 150, 160)
 p.Parent = clone
 return p
 end
 clone.PrimaryPart = part(Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
 part(Vector3.new(1, 1, 1), Vector3.new(0, 1.5, 0))
 part(Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
 part(Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
 part(Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
 part(Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
 end
 for _, d in ipairs(clone:GetDescendants()) do
 if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ForceField") then
 d:Destroy()
 elseif d:IsA("BasePart") then
 d.Anchored = true
 end
 end
 local hum = clone:FindFirstChildOfClass("Humanoid")
 if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

 -- Stand it upright facing the camera, whatever pose the real
 -- character was in (falling, ragdolled, turned away).
 local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
 if root then
 local offset = root.CFrame:ToObjectSpace(clone:GetPivot())
 clone:PivotTo(CFrame.Angles(0, math.pi, 0) * offset)
 end
 -- Centre the model on the origin.
 local cf = clone:GetBoundingBox()
 clone:PivotTo(clone:GetPivot() - cf.Position)
 clone.Parent = viewport
 model = clone
 model:SetAttribute("BasePivot", model:GetPivot())

 -- Back the camera off until both height and width fit.
 local size = select(2, model:GetBoundingBox())
 local t = math.tan(math.rad(camera.FieldOfView / 2))
 local aspect = W / math.max(1, (opts.Height or self._height) - HEADER)
 local dist = math.max((size.Y / 2) / t, (math.max(size.X, size.Z) / 2) / (t * aspect)) * 1.45
 camera.CFrame = CFrame.new(Vector3.new(0, 0.4, dist), Vector3.new(0, 0, 0))
 end
 buildModel()

 -- 2D overlay ----------------------------------------------------------
 local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = stage })
 local box = new("Frame", { BackgroundTransparency = 1, Parent = overlay })
 local boxStroke = stroke(WHITE, 1, 0)
 boxStroke.Parent = box
 local corners = {}
 for i = 1, 8 do
 corners[i] = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Parent = overlay })
 end
 local nameLabel = new("TextLabel", {
 AnchorPoint = Vector2.new(0.5, 1),
 Size = UDim2.fromOffset(160, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = LocalPlayer.DisplayName,
 TextColor3 = WHITE,
 TextSize = 11,
 TextStrokeTransparency = 0.5,
 Parent = overlay,
 })
 local distLabel = new("TextLabel", {
 AnchorPoint = Vector2.new(0.5, 0),
 Size = UDim2.fromOffset(160, 12),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 TextColor3 = Theme.SubText,
 TextSize = 10,
 TextStrokeTransparency = 0.5,
 Parent = overlay,
 })
 local healthBack = new("Frame", {
 AnchorPoint = Vector2.new(1, 0),
 BackgroundColor3 = Color3.new(0, 0, 0),
 BackgroundTransparency = 0.4,
 BorderSizePixel = 0,
 Parent = overlay,
 })
 local healthFill = new("Frame", {
 AnchorPoint = Vector2.new(0, 1),
 Position = UDim2.fromScale(0, 1),
 BackgroundColor3 = Theme.Success,
 BorderSizePixel = 0,
 Parent = healthBack,
 })
 local tracer = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 BackgroundColor3 = WHITE,
 BorderSizePixel = 0,
 Parent = overlay,
 })
 local fill = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0.82, ZIndex = 0, Parent = overlay })
 -- Chakra (right, fills up) and blood (bottom, fills right) bars.
 local function barPair(color, anchorFill)
 local back = new("Frame", {
 BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0,
 Visible = false, Parent = overlay,
 })
 local f = new("Frame", {
 AnchorPoint = anchorFill, Position = UDim2.fromScale(anchorFill.X, anchorFill.Y),
 BackgroundColor3 = color, BorderSizePixel = 0, Parent = back,
 })
 return back, f
 end
 local chakraBack, chakraFill = barPair(Color3.fromRGB(70, 160, 255), Vector2.new(0, 1))
 local bloodBack, bloodFill = barPair(Color3.fromRGB(200, 30, 45), Vector2.new(0, 0))
 -- Rotated 1px frames drawing a line between two stage points.
 local function lineFrame()
 return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = WHITE, Parent = overlay })
 end
 local function placeLine(f, a, b, color)
 local d = b - a
 f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
 f.Size = UDim2.fromOffset(d.Magnitude, 1)
 f.Rotation = math.deg(math.atan2(d.Y, d.X))
 f.BackgroundColor3 = color
 f.Visible = true
 end
 local bones = {}
 for i = 1, 14 do bones[i] = lineFrame() end
 local BONES_R15 = {
 { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
 { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
 { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
 { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
 { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
 }
 local stack = {}
 for i = 1, 8 do
 stack[i] = new("TextLabel", {
 AnchorPoint = Vector2.new(0.5, 1),
 Size = UDim2.fromOffset(200, 12),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 TextColor3 = WHITE,
 TextSize = 10,
 TextStrokeTransparency = 0.4,
 Visible = false,
 Parent = overlay,
 })
 end

 -- Drag the stage to turn the model.
 local dragArea = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 4,
 Parent = stage,
 })

 -- Project a world point into stage pixels (vertical FOV camera).
 local function project(p, stageSize)
 local rel = camera.CFrame:PointToObjectSpace(p)
 local depth = -rel.Z
 if depth <= 0.01 then return nil end
 local t = math.tan(math.rad(camera.FieldOfView / 2))
 local aspect = stageSize.X / stageSize.Y
 local nx = rel.X / (depth * t * aspect)
 local ny = rel.Y / (depth * t)
 return Vector2.new((nx + 1) / 2 * stageSize.X, (1 - ny) / 2 * stageSize.Y)
 end

 local preview = { Panel = panel, Detached = false, Spinning = true }
 local angle, visibleWanted = 0, true
 local spinIcon, detachIcon

 -- Header buttons (right to left): close, detach, spin lock, reset.
 local toggleEl
 headerButton("x", 1, "Hide preview", function()
 if toggleEl then toggleEl:Set(false) else preview:SetVisible(false) end
 end)
 local _
 _, detachIcon = headerButton("external-link", 2, function()
 return preview.Detached and "Dock to the window" or "Detach and float"
 end, function() preview:SetDetached(not preview.Detached) end)
 _, spinIcon = headerButton("unlock", 3, function()
 return preview.Spinning and "Lock rotation" or "Unlock rotation"
 end, function() preview:SetSpinning(not preview.Spinning) end)
 headerButton("rotate-ccw", 4, "Reset view", function() preview:ResetView() end)

 function preview:SetSpinning(on)
 self.Spinning = on
 spinIcon.Image = resolveIcon(on and "unlock" or "lock")
 spinIcon.ImageColor3 = on and Theme.Muted or Theme.Accent
 end

 function preview:ResetView()
 angle = 0
 buildModel()
 end

 -- Docked: lives in the window's root (moves and scales with it).
 -- Detached: lives in the ScreenGui at the same on-screen spot, with its
 -- own scale, and can be dragged by the header.
 function preview:SetDetached(on)
 if on == self.Detached then return end
 self.Detached = on
 local window = preview._window
 if on then
 local inset = game:GetService("GuiService"):GetGuiInset()
 local abs = panel.AbsolutePosition
 local unscaledH = panel.AbsoluteSize.Y / window:_layoutScale()
 local idx = table.find(window._attached, panel)
 if idx then table.remove(window._attached, idx) end
 panel.Parent = window.Gui
 panel.Size = UDim2.fromOffset(W, unscaledH)
 panelScale.Scale = window.BaseScale
 panel.Position = UDim2.fromOffset(abs.X, abs.Y + inset.Y)
 panel.GroupTransparency = 0
 detachIcon.ImageColor3 = Theme.Accent
 else
 panel.Parent = window.Root
 panel.Size = dockedSize
 panel.Position = UDim2.new(1, 12, 0, 0)
 panelScale.Scale = 1
 table.insert(window._attached, panel)
 panel.GroupTransparency = window.Main.GroupTransparency
 detachIcon.ImageColor3 = Theme.Muted
 end
 end
 preview._window = self

 -- Header drag (detached only)
 local dragStart, startPos
 header.InputBegan:Connect(function(input)
 if preview.Detached and isMouseOrTouch(input) then
 dragStart, startPos = input.Position, panel.Position
 end
 end)
 -- Stage drag turns the model
 local turning, lastX
 dragArea.InputBegan:Connect(function(input)
 if isMouseOrTouch(input) then turning, lastX = true, input.Position.X end
 end)
 table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
 if not isMove(input) then return end
 if dragStart then
 local d = input.Position - dragStart
 panel.Position = startPos + UDim2.fromOffset(d.X, d.Y)
 elseif turning then
 angle += (input.Position.X - lastX) * 0.012
 lastX = input.Position.X
 end
 end))
 table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
 if isMouseOrTouch(input) then dragStart, turning = nil, false end
 end))

 local conn = RunService.RenderStepped:Connect(function(dt)
 local show = visibleWanted and (preview.Detached
 or (self.Visible and (not opts.Tab or self.ActiveTab == opts.Tab)))
 panel.Visible = show
 if not show or not model or not model.Parent then return end
 if preview.Detached then panelScale.Scale = self.BaseScale end

 if preview.Spinning and not turning and not Prism.ReduceMotion then angle += dt * 0.7 end
 model:PivotTo(CFrame.Angles(0, angle, 0) * model:GetAttribute("BasePivot"))

 local s = panel.AbsoluteSize.X / W
 local stageSize = stage.AbsoluteSize / s
 local cf, size = model:GetBoundingBox()
 local minV, maxV = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
 for _, x in ipairs({ -0.5, 0.5 }) do
 for _, y in ipairs({ -0.5, 0.5 }) do
 for _, z in ipairs({ -0.5, 0.5 }) do
 local v = project((cf * CFrame.new(size.X * x, size.Y * y, size.Z * z)).Position, stageSize)
 if v then
 minV = Vector2.new(math.min(minV.X, v.X), math.min(minV.Y, v.Y))
 maxV = Vector2.new(math.max(maxV.X, v.X), math.max(maxV.Y, v.Y))
 end
 end
 end
 end
 local bw, bh = maxV.X - minV.X, maxV.Y - minV.Y
 floor.Position = UDim2.fromOffset(minV.X + bw / 2, maxV.Y)
 local boxOn = read("Box")
 local boxColor = read("BoxColor") or WHITE
 local cornerStyle = read("BoxStyle") == "Corner"

 box.Visible = boxOn and not cornerStyle
 box.Position = UDim2.fromOffset(minV.X, minV.Y)
 box.Size = UDim2.fromOffset(bw, bh)
 boxStroke.Color = boxColor

 -- Corner style: eight short lines
 local cl = math.min(bw, bh) * 0.22
 local cspec = {
 { minV.X, minV.Y, cl, 1 }, { minV.X, minV.Y, 1, cl },
 { maxV.X - cl, minV.Y, cl, 1 }, { maxV.X - 1, minV.Y, 1, cl },
 { minV.X, maxV.Y - 1, cl, 1 }, { minV.X, maxV.Y - cl, 1, cl },
 { maxV.X - cl, maxV.Y - 1, cl, 1 }, { maxV.X - 1, maxV.Y - cl, 1, cl },
 }
 for i, c in ipairs(corners) do
 local spec = cspec[i]
 c.Visible = boxOn and cornerStyle
 c.Position = UDim2.fromOffset(spec[1], spec[2])
 c.Size = UDim2.fromOffset(spec[3], spec[4])
 c.BackgroundColor3 = boxColor
 end

 fill.Visible = (boxOn and read("BoxFill")) and true or false
 fill.Position = UDim2.fromOffset(minV.X, minV.Y)
 fill.Size = UDim2.fromOffset(bw, bh)
 fill.BackgroundColor3 = boxColor

 -- Skeleton from the clone's own parts. R6 limbs run from the
 -- shoulder / hip joint to the end of the hand / foot.
 local skelOn = read("Skeleton")
 local hum = model:FindFirstChildOfClass("Humanoid")
 local segs = {}
 if skelOn then
 if hum and hum.RigType == Enum.HumanoidRigType.R15 then
 for _, pair in ipairs(BONES_R15) do
 local a, b = model:FindFirstChild(pair[1]), model:FindFirstChild(pair[2])
 if a and b then table.insert(segs, { a.Position, b.Position }) end
 end
 else
 local torso, head = model:FindFirstChild("Torso"), model:FindFirstChild("Head")
 if torso then
 local half = torso.Size.Y / 2
 local neck = (torso.CFrame * CFrame.new(0, half, 0)).Position
 local pelvis = (torso.CFrame * CFrame.new(0, -half, 0)).Position
 if head then table.insert(segs, { head.Position, neck }) end
 table.insert(segs, { neck, pelvis })
 for _, l in ipairs({ { "Left Arm", neck }, { "Right Arm", neck }, { "Left Leg", pelvis }, { "Right Leg", pelvis } }) do
 local part = model:FindFirstChild(l[1])
 if part then
 local h = part.Size.Y / 2
 local top = (part.CFrame * CFrame.new(0, h * 0.8, 0)).Position
 table.insert(segs, { l[2], top })
 table.insert(segs, { top, (part.CFrame * CFrame.new(0, -h, 0)).Position })
 end
 end
 end
 end
 end
 for i, f in ipairs(bones) do
 local sg = segs[i]
 local pa = sg and project(sg[1], stageSize)
 local pb = sg and project(sg[2], stageSize)
 if pa and pb then placeLine(f, pa, pb, read("SkeletonColor") or WHITE) else f.Visible = false end
 end

 -- Text stack (script-supplied) or the plain name label
 local lines = read("Lines")
 if type(lines) == "table" then
 nameLabel.Visible = false
 local y = minV.Y - 3
 for i, lbl in ipairs(stack) do
 local ln = lines[i]
 if ln then
 lbl.Text = tostring(ln.Text or ln[1] or "")
 lbl.TextColor3 = ln.Color or ln[2] or WHITE
 lbl.Position = UDim2.fromOffset(minV.X + bw / 2, y)
 lbl.Visible = true
 y -= 12
 else
 lbl.Visible = false
 end
 end
 else
 for _, lbl in ipairs(stack) do lbl.Visible = false end
 nameLabel.Visible = read("Name") and true or false
 end
 nameLabel.Position = UDim2.fromOffset(minV.X + bw / 2, minV.Y - 3)
 nameLabel.TextColor3 = read("NameColor") or WHITE

 distLabel.Visible = read("Distance") and true or false
 distLabel.Position = UDim2.fromOffset(minV.X + bw / 2, maxV.Y + 3 + ((read("Blood") and (tonumber(read("BarWidth")) or 3) + 4) or 0))
 distLabel.Text = string.format("[%dm]", 24 + math.floor(math.sin(os.clock() * 0.8) * 6))

 local barW = tonumber(read("BarWidth")) or 3
 local hp = 0.55 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 1.3))
 healthBack.Visible = read("Health") and true or false
 healthBack.Position = UDim2.fromOffset(minV.X - barW - 2, minV.Y)
 healthBack.Size = UDim2.fromOffset(barW, bh)

 local ck = 0.4 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 0.9 + 1))
 chakraBack.Visible = read("Chakra") and true or false
 chakraBack.Position = UDim2.fromOffset(maxV.X + 2, minV.Y)
 chakraBack.Size = UDim2.fromOffset(barW, bh)
 chakraFill.Size = UDim2.fromScale(1, ck)

 local bloodOn = read("Blood") and true or false
 local bl = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 0.7 + 2))
 bloodBack.Visible = bloodOn
 bloodBack.Position = UDim2.fromOffset(minV.X, maxV.Y + 3)
 bloodBack.Size = UDim2.fromOffset(bw, barW)
 bloodFill.Size = UDim2.fromScale(bl, 1)
 healthFill.Size = UDim2.fromScale(1, hp)
 healthFill.BackgroundColor3 = Theme.Error:Lerp(Theme.Success, hp)

 -- Tracer from the bottom centre of the stage to the box's feet.
 local from = Vector2.new(stageSize.X / 2, stageSize.Y)
 local to = Vector2.new(minV.X + bw / 2, maxV.Y)
 local delta = to - from
 tracer.Visible = read("Tracer") and true or false
 tracer.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
 tracer.Size = UDim2.fromOffset(delta.Magnitude, 1)
 tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
 tracer.BackgroundColor3 = read("TracerColor") or WHITE
 end)
 table.insert(self._conns, conn)

 -- Rebuild when the character respawns or changes outfit.
 table.insert(self._conns, LocalPlayer.CharacterAppearanceLoaded:Connect(function()
 task.wait(0.5)
 buildModel()
 end))

 function preview:SetVisible(on) visibleWanted = on end
 function preview:Rebuild() buildModel() end
 function preview:Destroy()
 conn:Disconnect()
 panel:Destroy()
 end

 -- Optional show / hide toggle in a section of your choice.
 if opts.Section then
 toggleEl = opts.Section:Toggle({
 Name = opts.ToggleName or "ESP preview",
 Description = "Shows a live preview of your ESP settings.",
 Default = opts.Visible ~= false,
 Flag = opts.Flag or "Prism_ESPPreview",
 HideFromList = true,
 Callback = function(on) preview:SetVisible(on) end,
 })
 end
 preview:SetVisible(opts.Visible ~= false)
 return preview
end

-- ============================================================================
-- HOME
-- ============================================================================
-- A dashboard that opens when the profile card (avatar, name, badge) at
-- the bottom of the sidebar is clicked. It has no sidebar entry of its own.
-- Built the first time it opens, from CreateWindow{ Home = { ... } }:
--
-- Home = {
-- Message = "Thanks for using Prism!",
-- Discord = "https://discord.gg/...",
-- Changelog = {
-- { Version = "3.1", Date = "Oct 2026", Notes = { "Added ...", "Fixed ..." } },
-- },
-- }
-- ============================================================================
function Window:OpenHome()
 if not self._home then self:_buildHome() end
 self:SelectTab(self._home)
end

function Window:_buildHome()
 local cfg = self._homeConfig or {}
 local home = self:Tab({ Name = "Home", Icon = "home", Description = "Welcome back" })
 home.Button.Visible = false
 self._home = home

 -- Hero card -------------------------------------------------------------
 local stack, card = sectionCard(home.Left, self)
 card.LayoutOrder = -1
 local hero = new("Frame", {
 Size = UDim2.new(1, 0, 0, 132),
 BackgroundTransparency = 1,
 ClipsDescendants = true,
 Parent = stack,
 })
 -- Accent wash fading down
 bindAccent(new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 0.8,
 BorderSizePixel = 0,
 Parent = hero,
 }, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) }), "BackgroundColor3")
 local avatar = new("ImageLabel", {
 Position = UDim2.fromOffset(16, 18),
 Size = UDim2.fromOffset(56, 56),
 BackgroundColor3 = Theme.Element,
 BorderSizePixel = 0,
 Parent = hero,
 }, { corner("full") })
 local ring = stroke(WHITE, 2, 0)
 ring.Parent = avatar
 accentGradient(ring, 45)
 task.spawn(function()
 local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
 if ok then avatar.Image = img end
 end)
 new("TextLabel", {
 Position = UDim2.fromOffset(86, 16),
 Size = UDim2.new(1, -100, 0, 13),
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = "Welcome back",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = hero,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(86, 29),
 Size = UDim2.new(1, -100, 0, 18),
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = LocalPlayer.DisplayName,
 TextColor3 = Theme.Text,
 TextSize = 15,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = hero,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(86, 47),
 Size = UDim2.new(1, -100, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "@" .. LocalPlayer.Name,
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = hero,
 })
 local tagRow = new("Frame", {
 Position = UDim2.fromOffset(86, 64),
 Size = UDim2.new(1, -100, 0, 16),
 BackgroundTransparency = 1,
 Parent = hero,
 }, {
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 6),
 SortOrder = Enum.SortOrder.LayoutOrder,
 }),
 })
 if self.User and self.User.Tag then
 local badge = accentFill({
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 LayoutOrder = 1,
 Parent = tagRow,
 }, 4)
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(self.User.Tag),
 TextColor3 = WHITE,
 TextSize = 9,
 ZIndex = 2,
 Parent = badge,
 }, { padding(0, 0, 6, 6) })
 end
 if self.User and self.User.Expiry then
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 16),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = self.User.Expiry,
 TextColor3 = Theme.SubText,
 TextSize = 11,
 LayoutOrder = 2,
 Parent = tagRow,
 })
 end
 new("TextLabel", {
 Position = UDim2.fromOffset(16, 92),
 Size = UDim2.new(1, -32, 0, 30),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = cfg.Message or ("Thanks for using " .. self.Title .. "."),
 TextColor3 = Theme.SubText,
 TextSize = 11,
 TextWrapped = true,
 TextYAlignment = Enum.TextYAlignment.Top,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = hero,
 })

 -- Account ---------------------------------------------------------------
 local account = home:Section({ Name = "Account", Icon = "user", Side = "Left" })
 account:Stat({ Name = "User id", Value = tostring(LocalPlayer.UserId), Icon = "hash" })
 account:Stat({ Name = "Account age", Value = LocalPlayer.AccountAge .. " days", Icon = "clock" })
 account:Stat({ Name = "Membership", Value = LocalPlayer.MembershipType == Enum.MembershipType.Premium and "Roblox Premium" or "Standard", Icon = "star" })
 if self.User then
 account:Stat({ Name = "Access", Value = self.User.Expiry or "-", Icon = "key" })
 end

 -- Session ---------------------------------------------------------------
 local session = home:Section({ Name = "Session", Icon = "activity", Side = "Left" })
 local executor = "Unknown"
 pcall(function() executor = identifyexecutor and (identifyexecutor()) or executor end)
 session:Stat({ Name = "Executor", Value = executor, Icon = "terminal" })
 local gameStat = session:Stat({ Name = "Game", Value = "...", Icon = "gamepad-2" })
 task.spawn(function()
 local ok, product = pcall(function()
 return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
 end)
 gameStat:Set(ok and product and product.Name or tostring(game.PlaceId))
 end)
 local timeStat = session:Stat({ Name = "Time in session", Icon = "timer" })
 local configStat = session:Stat({ Name = "Saved configs", Icon = "save" })
 local started = self._started or os.clock()
 task.spawn(function()
 while self.Gui.Parent do
 local t = math.floor(os.clock() - started)
 timeStat:Set(string.format("%02d:%02d:%02d", t // 3600, t // 60 % 60, t % 60))
 configStat:Set(tostring(#self:ListConfigs()))
 task.wait(1)
 end
 end)

 -- Changelog -------------------------------------------------------------
 local changelog = home:Section({ Name = "What's new", Icon = "gem", Side = "Right" })
 local entries = cfg.Changelog or { { Version = Prism.Version, Notes = { "You're on the latest version." } } }
 for i, entry in ipairs(entries) do
 if i > 1 then changelog:Divider() end
 local lines = {}
 for _, note in ipairs(entry.Notes or {}) do table.insert(lines, "• " .. note) end
 changelog:Paragraph({
 Title = "v" .. tostring(entry.Version) .. (entry.Date and (' ' .. entry.Date .. " ") or ""),
 Content = table.concat(lines, "\n"),
 })
 end

 -- Quick actions ---------------------------------------------------------
 local quick = home:Section({ Name = "Quick actions", Icon = "rocket", Side = "Right" })
 local row = {}
 if cfg.Discord then
 table.insert(row, {
 Name = "Discord",
 Icon = "users",
 Callback = function()
 if setclipboard then
 setclipboard(cfg.Discord)
 Prism:Notify({ Title = "Invite copied", Content = "Paste it in your browser to join.", Type = "Success" })
 end
 end,
 })
 end
 table.insert(row, {
 Name = "Settings",
 Icon = "settings",
 Callback = function()
 for _, t in ipairs(self.Tabs) do
 if t.Name == "Settings" then self:SelectTab(t) end
 end
 end,
 })
 quick:ButtonRow(row)
 quick:Button({ Name = "Search everything", Icon = "search", Description = "Ctrl+K", Callback = function() self:OpenSearch() end })
end

-- ============================================================================
-- CLOUD CONFIG SHARING
-- ============================================================================
-- Window:ShareConfig() uploads the current config and returns a short
-- code; Window:ImportShared(code) downloads and applies one. Friends paste
-- the code into Settings -> Configs -> Import code.
--
-- Prism.CloudProvider decides where configs go. The default uses paste.rs
-- (no account needed). Swap it for your own backend:
--
-- Prism.CloudProvider = {
-- Upload = function(text) ... return code end,
-- Download = function(code) ... return text end,
-- }
-- ============================================================================
local function httpRequest(req)
 local fn = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
 if not fn then error("Your executor doesn't support HTTP requests.") end
 return fn(req)
end

Prism.CloudProvider = {
 Upload = function(text)
 local res = httpRequest({ Url = "https://paste.rs/", Method = "POST", Body = text })
 if not res or (res.StatusCode ~= 201 and res.StatusCode ~= 206) then
 error("Upload failed (" .. tostring(res and res.StatusCode) .. ")")
 end
 return string.match(res.Body, "([%w]+)%s*$")
 end,
 Download = function(code)
 local res = httpRequest({ Url = "https://paste.rs/" .. code, Method = "GET" })
 if not res or res.StatusCode ~= 200 then
 error("Code not found (" .. tostring(res and res.StatusCode) .. ")")
 end
 return res.Body
 end,
}

-- Shared configs carry a marker so random pastes are rejected.
local SHARE_MARK = "prism-config:"

function Window:ShareConfig()
 local ok, code = pcall(Prism.CloudProvider.Upload, SHARE_MARK .. self:ExportConfig())
 if ok and code then return code end
 return nil, tostring(code)
end

function Window:ImportShared(code)
 code = (code or ""):gsub("%s", ""):gsub("^.*/", "")
 if code == "" then return false, "Enter a code." end
 local ok, text = pcall(Prism.CloudProvider.Download, code)
 if not ok then return false, tostring(text) end
 if string.sub(text, 1, #SHARE_MARK) ~= SHARE_MARK then
 return false, "That code isn't a Prism config."
 end
 if self:ImportConfig(string.sub(text, #SHARE_MARK + 1)) then return true end
 return false, "That config couldn't be read."
end

-- ============================================================================
-- KEY SYSTEM
-- ============================================================================
-- Prism:KeySystem{
-- Title = "Prism",
-- Subtitle = "Enter your key to continue",
-- Note = "Keys last 24 hours.",
-- KeyLink = "https://...", -- "Get key" copies this
-- Discord = "https://discord.gg/...",
-- SaveKey = true, -- remember a valid key
-- Closable = false, -- adds an X; closing returns nil
-- Folder = "Prism",
-- Validate = function(key) return ok, message end,
-- } -> key (blocks until a valid key is entered, or nil if closed)
--
-- Validate can yield (HTTP checks). With Luarmor, for example:
-- local api = loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
-- api.script_id = "YOUR_SCRIPT_ID"
-- Validate = function(key)
-- local status = api.check_key(key)
-- if status.code == "KEY_VALID" then
-- getgenv().script_key = key
-- return true
-- end
-- return false, status.message
-- end
-- ============================================================================
function Prism:KeySystem(opts)
 opts = opts or {}
 local validate = opts.Validate or function() return true end
 local folder = opts.Folder or "Prism"
 local keyFile = folder .. "/key.txt"
 local canSave = opts.SaveKey ~= false and writefile and readfile and isfile and isfolder and makefolder

 local gui = new("ScreenGui", {
 Name = "PrismKey",
 ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
 IgnoreGuiInset = true,
 ResetOnSpawn = false,
 DisplayOrder = 1001,
 })
 guiParent(gui)

 local overlay = new("Frame", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Color3.fromRGB(5, 4, 10),
 BackgroundTransparency = 1,
 BorderSizePixel = 0,
 Parent = gui,
 })
 local blur
 pcall(function() blur = new("BlurEffect", { Name = "PrismBlur", Size = 0, Parent = Lighting }) end)
 tween(overlay, 0.4, { BackgroundTransparency = 0.35 })
 if blur then tween(blur, 0.4, { Size = 16 }) end

 local holder = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 Size = UDim2.fromOffset(340, 300),
 BackgroundTransparency = 1,
 Parent = gui,
 })
 local holderScale = new("UIScale", { Scale = 0.94, Parent = holder })
 local underglow = bindAccent(new("ImageLabel", {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.new(0.5, 0, 0.5, 16),
 Size = UDim2.new(1, 140, 1, 140),
 BackgroundTransparency = 1,
 Image = "rbxassetid://8992230677",
 ScaleType = Enum.ScaleType.Slice,
 SliceCenter = Rect.new(99, 99, 99, 99),
 ImageTransparency = 1,
 Parent = holder,
 }), "ImageColor3")
 local shadow = dropShadow(holder, "Window")
 shadow.ImageTransparency = 1

 local card = new("CanvasGroup", {
 Size = UDim2.fromScale(1, 1),
 BackgroundColor3 = Theme.Background,
 BorderSizePixel = 0,
 GroupTransparency = 1,
 Parent = holder,
 }, { corner(12), outline(0.88) })

 -- Accent wash at the top
 bindAccent(new("Frame", {
 Size = UDim2.new(1, 0, 0, 120),
 BackgroundTransparency = 0.82,
 BorderSizePixel = 0,
 Parent = card,
 }, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }) }), "BackgroundColor3")

 local logoHolder = new("Frame", {
 AnchorPoint = Vector2.new(0.5, 0),
 Position = UDim2.new(0.5, 0, 0, 26),
 Size = UDim2.fromOffset(46, 46),
 BackgroundTransparency = 1,
 Parent = card,
 })
 buildLogo(logoHolder, { Scale = 46 / LOGO_SIZE }).Holder.Position = UDim2.fromScale(0.5, 0.5)

 new("TextLabel", {
 Position = UDim2.fromOffset(0, 82),
 Size = UDim2.new(1, 0, 0, 20),
 BackgroundTransparency = 1,
 FontFace = Fonts.Bold,
 Text = string.upper(opts.Title or "Prism"),
 TextColor3 = Theme.Text,
 TextSize = 17,
 Parent = card,
 })
 new("TextLabel", {
 Position = UDim2.fromOffset(0, 104),
 Size = UDim2.new(1, 0, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Subtitle or "Enter your key to continue",
 TextColor3 = Theme.SubText,
 TextSize = 12,
 Parent = card,
 })

 -- Key input
 local field = new("Frame", {
 Position = UDim2.fromOffset(24, 136),
 Size = UDim2.new(1, -48, 0, 34),
 BackgroundColor3 = Theme.Input,
 BorderSizePixel = 0,
 Parent = card,
 }, { corner(7) })
 local fieldStroke = outline()
 fieldStroke.Parent = field
 icon("key", 14, Theme.Muted, {
 AnchorPoint = Vector2.new(0, 0.5),
 Position = UDim2.new(0, 11, 0.5, 0),
 Parent = field,
 })
 local box = new("TextBox", {
 Position = UDim2.fromOffset(34, 0),
 Size = UDim2.new(1, -44, 1, 0),
 BackgroundTransparency = 1,
 ClearTextOnFocus = false,
 FontFace = Fonts.Medium,
 PlaceholderText = "Paste your key...",
 PlaceholderColor3 = Theme.Muted,
 Text = "",
 TextColor3 = Theme.Text,
 TextSize = 12,
 TextTruncate = Enum.TextTruncate.AtEnd,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = field,
 })
 box.Focused:Connect(function() tween(fieldStroke, 0.15, { Color = Theme.Accent, Transparency = 0 }) end)
 box.FocusLost:Connect(function() tween(fieldStroke, 0.15, { Color = Theme.Outline, Transparency = Theme.OutlineTransparency }) end)

 local status = new("TextLabel", {
 Position = UDim2.fromOffset(24, 176),
 Size = UDim2.new(1, -48, 0, 14),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = opts.Note or "",
 TextColor3 = Theme.Muted,
 TextSize = 11,
 TextXAlignment = Enum.TextXAlignment.Left,
 Parent = card,
 })

 -- Buttons
 local continueFace = accentFill({
 Position = UDim2.fromOffset(24, 198),
 Size = UDim2.new(1, -48, 0, 34),
 Parent = card,
 }, 7)
 local continueLabel = new("TextLabel", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 FontFace = Fonts.SemiBold,
 Text = "Continue",
 TextColor3 = WHITE,
 TextSize = 13,
 ZIndex = 2,
 Parent = continueFace,
 })
 local continueHit = new("TextButton", {
 Size = UDim2.fromScale(1, 1),
 BackgroundTransparency = 1,
 Text = "",
 ZIndex = 3,
 Parent = continueFace,
 })
 continueHit.MouseEnter:Connect(function() tween(continueFace, 0.12, { GroupTransparency = 0.1 }) end)
 continueHit.MouseLeave:Connect(function() tween(continueFace, 0.12, { GroupTransparency = 0 }) end)

 local function secondary(text, iconName, x, onClick)
 local b = new("TextButton", {
 Position = UDim2.new(x, x == 0 and 24 or 4, 0, 240),
 Size = UDim2.new(0.5, -28, 0, 30),
 BackgroundColor3 = Theme.Element,
 AutoButtonColor = false,
 Text = "",
 Parent = card,
 }, {
 corner(7),
 outline(),
 new("UIListLayout", {
 FillDirection = Enum.FillDirection.Horizontal,
 HorizontalAlignment = Enum.HorizontalAlignment.Center,
 VerticalAlignment = Enum.VerticalAlignment.Center,
 Padding = UDim.new(0, 6),
 }),
 })
 icon(iconName, 12, Theme.SubText, { Parent = b })
 new("TextLabel", {
 Size = UDim2.fromOffset(0, 14),
 AutomaticSize = Enum.AutomaticSize.X,
 BackgroundTransparency = 1,
 FontFace = Fonts.Medium,
 Text = text,
 TextColor3 = Theme.Text,
 TextSize = 12,
 Parent = b,
 })
 b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.ElementHover }) end)
 b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.Element }) end)
 b.MouseButton1Click:Connect(onClick)
 end
 local function copy(text, what)
 if text and setclipboard then
 setclipboard(text)
 status.Text = what .. " copied to clipboard."
 status.TextColor3 = Theme.SubText
 end
 end
 secondary("Get key", "external-link", 0, function() copy(opts.KeyLink, "Key link") end)
 secondary("Discord", "users", 0.5, function() copy(opts.Discord, "Discord invite") end)

 new("TextLabel", {
 AnchorPoint = Vector2.new(0, 1),
 Position = UDim2.new(0, 0, 1, -8),
 Size = UDim2.new(1, 0, 0, 12),
 BackgroundTransparency = 1,
 FontFace = Fonts.Regular,
 Text = "v" .. Prism.Version,
 TextColor3 = Theme.Muted,
 TextSize = 10,
 TextTransparency = 0.4,
 Parent = card,
 })

 -- Show
 tween(card, 0.4, { GroupTransparency = 0 })
 tween(shadow, 0.4, { ImageTransparency = 0.4 })
 tween(underglow, 0.6, { ImageTransparency = 0.85 })
 tween(holderScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

 local done, busy, closed = nil, false, false

 if opts.Closable then
 local x = new("TextButton", {
 AnchorPoint = Vector2.new(1, 0),
 Position = UDim2.new(1, -10, 0, 10),
 Size = UDim2.fromOffset(24, 24),
 BackgroundColor3 = Theme.ElementHover,
 BackgroundTransparency = 1,
 AutoButtonColor = false,
 Text = "",
 ZIndex = 5,
 Parent = card,
 }, { corner(6) })
 local xIcon = icon("x", 13, Theme.Muted, {
 AnchorPoint = Vector2.new(0.5, 0.5),
 Position = UDim2.fromScale(0.5, 0.5),
 ZIndex = 5,
 Parent = x,
 })
 x.MouseEnter:Connect(function()
 tween(x, 0.12, { BackgroundTransparency = 0 })
 tween(xIcon, 0.12, { ImageColor3 = Theme.Text })
 end)
 x.MouseLeave:Connect(function()
 tween(x, 0.12, { BackgroundTransparency = 1 })
 tween(xIcon, 0.12, { ImageColor3 = Theme.Muted })
 end)
 x.MouseButton1Click:Connect(function() closed = true end)
 end

 local function shake()
 local base = holder.Position
 for _, dx in ipairs({ -10, 9, -7, 5, -3, 0 }) do
 tween(holder, 0.05, { Position = base + UDim2.fromOffset(dx, 0) }, Enum.EasingStyle.Linear).Completed:Wait()
 end
 holder.Position = base
 end

 local function check(key, silent)
 if busy then return end
 key = (key or ""):gsub("^%s+", ""):gsub("%s+$", "")
 if key == "" then
 status.Text = "Paste a key first."
 status.TextColor3 = Theme.Warning
 task.spawn(shake)
 return
 end
 busy = true
 continueLabel.Text = "Checking..."
 status.Text = silent and "Checking saved key..." or "Checking key..."
 status.TextColor3 = Theme.SubText
 local ok, valid, message = pcall(validate, key)
 busy = false
 if ok and valid then
 continueLabel.Text = "Key valid"
 status.Text = "Welcome back."
 status.TextColor3 = Theme.Success
 playSound("Notify")
 if canSave then
 pcall(function()
 if not isfolder(folder) then makefolder(folder) end
 writefile(keyFile, key)
 end)
 end
 done = key
 else
 continueLabel.Text = "Continue"
 status.Text = (ok and message) or (not ok and "Couldn't check the key. Try again.") or "That key isn't valid."
 status.TextColor3 = Theme.Error
 if canSave and silent then pcall(function() if delfile then delfile(keyFile) end end) end
 if not silent then task.spawn(shake) end
 end
 end

 continueHit.MouseButton1Click:Connect(function() check(box.Text) end)
 box.FocusLost:Connect(function(enter) if enter then check(box.Text) end end)

 -- Saved key: check it straight away.
 if canSave and isfile(keyFile) then
 local saved = readfile(keyFile)
 box.Text = saved
 task.spawn(check, saved, true)
 end

 repeat task.wait() until done or closed

 task.wait(0.35)
 tween(card, 0.3, { GroupTransparency = 1 })
 tween(shadow, 0.3, { ImageTransparency = 1 })
 tween(underglow, 0.3, { ImageTransparency = 1 })
 tween(holderScale, 0.3, { Scale = 0.96 })
 tween(overlay, 0.35, { BackgroundTransparency = 1 })
 if blur then tween(blur, 0.35, { Size = 0 }) end
 task.wait(0.36)
 gui:Destroy()
 if blur then blur:Destroy() end
 return done
end

-- ============================================================================
-- DEPENDENT ELEMENTS
-- ============================================================================
-- Any element can take DependsOn: it's only shown (or only unlocked) while
-- the condition holds.
--
-- DependsOn = "EspBox" -- that toggle is on
-- DependsOn = { Flag = "Mode", Value = "Rage" } -- a flag equals a value
-- DependsOn = { Flag = "Mode", Value = { "A", "B" } } -- one of several
-- DependsOn = { "EspBox", "EspName" } -- all of these are on
-- DependsOn = function() return ... end -- anything you like
-- DependMode = "Hide" (default) | "Lock" -- hide it, or grey it out
-- DependText = "Turn on Boxes first" -- lock message
-- ============================================================================
local function dependencyMet(dep)
 local kind = typeof(dep)
 if kind == "function" then
 local ok, result = pcall(dep)
 return ok and result and true or false
 elseif kind == "string" then
 local f = Prism.Flags[dep]
 return f ~= nil and f.Value == true
 elseif kind == "table" then
 if dep.Flag then
 local f = Prism.Flags[dep.Flag]
 if not f then return false end
 if typeof(dep.Value) == "table" then return table.find(dep.Value, f.Value) ~= nil end
 if dep.Value == nil then return f.Value == true end
 return f.Value == dep.Value
 end
 for _, d in ipairs(dep) do
 if not dependencyMet(d) then return false end
 end
 return true
 end
 return true
end

-- ============================================================================
-- LIVE BINDINGS
-- ============================================================================
-- Any element takes Bind = source (or el:Bind(source, opts) later) and
-- follows that data on its own. A source is one of:
-- function() return value end polled every BindInterval s (default 0.25)
-- a ValueBase (IntValue, ...) follows .Changed
-- { instance, "Property" } follows the property
-- { instance, "@Attribute" } follows the attribute
-- Display elements (Stat, Paragraph, Progress) get every value the
-- source returns: Progress:Set(value, text), Paragraph:Set(title, content).
-- Inputs are set silently (callbacks don't fire; BindFires = true to fire),
-- and only when the source changes, so the user can still change them.
-- Format = function(...) return display end reshapes values first.
-- ============================================================================
local function bindKey(packed)
 local parts = table.create(packed.n)
 for i = 1, packed.n do
 local v = packed[i]
 if type(v) == "table" then
 local items = {}
 for _, item in ipairs(v) do table.insert(items, tostring(item)) end
 v = "{" .. table.concat(items, "\2") .. "}"
 end
 parts[i] = typeof(v) .. ":" .. tostring(v)
 end
 return table.concat(parts, "\1")
end

function Window:_bind(el, source, opts)
 opts = opts or {}
 local read, signal
 if typeof(source) == "function" then
 read = source
 elseif typeof(source) == "Instance" and source:IsA("ValueBase") then
 read = function() return source.Value end
 signal = source.Changed
 elseif typeof(source) == "table" and typeof(source[1]) == "Instance" and type(source[2]) == "string" then
 local inst, prop = source[1], source[2]
 if string.sub(prop, 1, 1) == "@" then
 local attr = string.sub(prop, 2)
 read = function() return inst:GetAttribute(attr) end
 signal = inst:GetAttributeChangedSignal(attr)
 else
 read = function() return inst[prop] end
 signal = inst:GetPropertyChangedSignal(prop)
 end
 else
 warn("[Prism] Bind: expected a function, a ValueBase or { Instance, \"Property\" }")
 return
 end

 local b = { Element = el, Interval = not signal and (opts.Interval or 0.25) or nil, Next = 0 }
 local function pull()
 local ok, packed = pcall(function() return table.pack(read()) end)
 if not ok then return end
 if opts.Format then
 ok, packed = pcall(function() return table.pack(opts.Format(table.unpack(packed, 1, packed.n))) end)
 if not ok then return end
 end
 local key = bindKey(packed)
 if key == b.Last then return end
 b.Last = key
 if opts.Apply then
 opts.Apply(table.unpack(packed, 1, packed.n))
 elseif el.Get then
 el:Set(packed[1], not opts.Fire)
 else
 el:Set(table.unpack(packed, 1, packed.n))
 end
 end
 b.Pull = pull
 if signal then
 b.Conn = signal:Connect(pull)
 table.insert(self._conns, b.Conn)
 end
 self._bindings[b] = true
 pull()

 if self._bindLoop then return b end
 self._bindLoop = true
 task.spawn(function()
 while self.Gui.Parent do
 local now = os.clock()
 for binding in pairs(self._bindings) do
 local frame = binding.Element.Frame
 if frame and not frame.Parent then
 self._bindings[binding] = nil
 if binding.Conn then binding.Conn:Disconnect() end
 elseif binding.Interval and now >= binding.Next then
 binding.Next = now + binding.Interval
 task.spawn(binding.Pull)
 end
 end
 task.wait(0.05)
 end
 end)
 return b
end

function Window:_unbind(el)
 for b in pairs(self._bindings) do
 if b.Element == el then
 self._bindings[b] = nil
 if b.Conn then b.Conn:Disconnect() end
 end
 end
end

-- ============================================================================
-- KEYBIND CONFLICTS
-- ============================================================================
-- Binding a key that's already in use (another toggle, a Keybind, or the
-- menu key) pops a warning with Unbind others / Undo / Keep both. Loading
-- a config checks every bind at once.
-- ============================================================================
function Window:_keyUsers(key, except)
 local out = {}
 if not key then return out end
 for _, t in ipairs(self._bindables) do
 if t ~= except and t.Key == key then
 table.insert(out, { Name = t.Name or t:GetName(), Clear = function() t:SetKey(nil) end })
 end
 end
 for _, k in ipairs(self._keybinds) do
 if k ~= except and not k._isMenu and k.Value == key and k.Frame.Parent then
 table.insert(out, { Name = k:GetName(), Clear = function() k:Set(nil) end })
 end
 end
 if self.ToggleKey == key and not (except and except._isMenu) then
 table.insert(out, { Name = "Menu key" })
 end
 return out
end

function Window:_warnKeyConflict(owner, key, undo)
 local others = self:_keyUsers(key, owner)
 if #others == 0 then return end
 local names, clearable = {}, {}
 for _, o in ipairs(others) do
 table.insert(names, " " .. o.Name .. " ")
 if o.Clear then table.insert(clearable, o) end
 end
 local buttons = {}
 if #clearable > 0 then
 table.insert(buttons, {
 Name = "Unbind others",
 Primary = true,
 Callback = function() for _, o in ipairs(clearable) do o.Clear() end end,
 })
 end
 table.insert(buttons, { Name = "Undo", Callback = undo })
 table.insert(buttons, { Name = "Keep both" })
 Prism:Notify({
 Title = "Key conflict",
 Content = " " .. key.Name .. " is also bound to " .. table.concat(names, ", ") .. ".",
 Type = "Warning",
 Duration = 10,
 Merge = false,
 Buttons = buttons,
 })
end

-- Every key bound more than once: { { Key, Names = { ... } }, ... }.
function Window:FindKeyConflicts()
 local byKey, order = {}, {}
 local function add(key, name)
 if not key then return end
 if not byKey[key] then
 byKey[key] = {}
 table.insert(order, key)
 end
 table.insert(byKey[key], name)
 end
 for _, t in ipairs(self._bindables) do add(t.Key, t.Name or t:GetName()) end
 for _, k in ipairs(self._keybinds) do
 if not k._isMenu and k.Frame.Parent then add(k.Value, k:GetName()) end
 end
 add(self.ToggleKey, "Menu key")
 local out = {}
 for _, key in ipairs(order) do
 if #byKey[key] > 1 then table.insert(out, { Key = key, Names = byKey[key] }) end
 end
 return out
end

function Window:_reportKeyConflicts()
 local conflicts = self:FindKeyConflicts()
 if #conflicts == 0 then return end
 local lines = {}
 for _, c in ipairs(conflicts) do
 table.insert(lines, " " .. c.Key.Name .. ": " .. table.concat(c.Names, ", "))
 end
 Prism:Notify({
 Title = #conflicts == 1 and "1 key conflict" or (#conflicts .. " key conflicts"),
 Content = table.concat(lines, "\n"),
 Type = "Warning",
 Duration = 8,
 })
end

-- Shared per-element extras, given to every element: live bindings,
-- change listeners, and DependsOn rules.
function Window:_depends(el, opts)
 opts = opts or {}
 function el.Bind(selfEl, source, bindOpts)
 self:_bind(selfEl, source, bindOpts)
 return selfEl
 end
 function el.Unbind(selfEl) self:_unbind(selfEl) end
 -- el:OnChanged(fn): runs fn alongside the element's own callback.
 local listeners
 function el.OnChanged(selfEl, fn)
 if not listeners then
 listeners = {}
 local field = selfEl._changeField or "Callback"
 local original = opts[field]
 opts[field] = function(...)
 safeCall(original, ...)
 for _, listener in ipairs(listeners) do safeCall(listener, ...) end
 end
 end
 table.insert(listeners, fn)
 return selfEl
 end
 if opts.Bind ~= nil then
 self:_bind(el, opts.Bind, { Format = opts.Format, Interval = opts.BindInterval, Fire = opts.BindFires })
 end

 if not opts.DependsOn then return end
 table.insert(self._deps, {
 Element = el,
 Rule = opts.DependsOn,
 Mode = opts.DependMode or "Hide",
 Text = opts.DependText,
 })
 if self._depLoop then return end
 self._depLoop = true
 task.spawn(function()
 while self.Gui.Parent do
 for _, d in ipairs(self._deps) do
 local met = dependencyMet(d.Rule)
 if met ~= d.Last then
 d.Last = met
 if d.Mode == "Lock" and d.Element.SetLocked then
 d.Element:SetLocked(not met, d.Text or "Locked")
 elseif d.Element.SetVisible then
 d.Element:SetVisible(met)
 elseif d.Element.Frame then
 d.Element.Frame.Visible = met
 end
 end
 end
 task.wait(0.1)
 end
 end)
end

-- ============================================================================
-- RE-EXECUTION
-- ============================================================================
-- Running the script again unloads the previous copy first: its features
-- are switched off (toggle callbacks fire with false), its unload hooks
-- run, its UI and background loops are removed, then this copy loads.
-- ============================================================================
function Prism:_unloadAll()
 for _, w in ipairs(Prism._windows or {}) do pcall(w.Unload, w) end
 for _, c in ipairs(Prism._libConns or {}) do c:Disconnect() end
 for gui in pairs(Prism._roots) do
 if gui.Parent then gui:Destroy() end
 end
 for _, name in ipairs({ "PrismBlur", "PrismMenuBlur" }) do
 local blur = Lighting:FindFirstChild(name)
 if blur then blur:Destroy() end
 end
end

do
 local env = (getgenv and getgenv()) or _G
 local previous = env.__PrismLibrary
 if previous and previous ~= Prism and previous._unloadAll then
 pcall(previous._unloadAll, previous)
 end
 env.__PrismLibrary = Prism
end

return Prism
