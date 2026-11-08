class_name WorldTour
extends RefCounted
## The campaign as a journey around the world: ten legs of ten stops, one city per
## level. Pure data, so the level map, the HUD and the win screen all name the same
## place, and a future campaign extension only appends stops here.

const STOPS_PER_LEG := 10
## [key of the leg title, country codes are not needed: each stop is [city, country_en, country_tr]]
const LEGS := [
	["LEG_EUROPE_WEST", [
		["Istanbul", "Türkiye", "Türkiye"], ["Athens", "Greece", "Yunanistan"], ["Rome", "Italy", "İtalya"],
		["Venice", "Italy", "İtalya"], ["Zurich", "Switzerland", "İsviçre"], ["Lyon", "France", "Fransa"],
		["Paris", "France", "Fransa"], ["Barcelona", "Spain", "İspanya"], ["Madrid", "Spain", "İspanya"],
		["Lisbon", "Portugal", "Portekiz"]]],
	["LEG_EUROPE_NORTH", [
		["London", "United Kingdom", "Birleşik Krallık"], ["Edinburgh", "United Kingdom", "Birleşik Krallık"],
		["Amsterdam", "Netherlands", "Hollanda"], ["Brussels", "Belgium", "Belçika"], ["Berlin", "Germany", "Almanya"],
		["Copenhagen", "Denmark", "Danimarka"], ["Oslo", "Norway", "Norveç"], ["Stockholm", "Sweden", "İsveç"],
		["Helsinki", "Finland", "Finlandiya"], ["Reykjavik", "Iceland", "İzlanda"]]],
	["LEG_EUROPE_EAST", [
		["Prague", "Czechia", "Çekya"], ["Vienna", "Austria", "Avusturya"], ["Budapest", "Hungary", "Macaristan"],
		["Kraków", "Poland", "Polonya"], ["Warsaw", "Poland", "Polonya"], ["Vilnius", "Lithuania", "Litvanya"],
		["Bucharest", "Romania", "Romanya"], ["Sofia", "Bulgaria", "Bulgaristan"], ["Belgrade", "Serbia", "Sırbistan"],
		["Dubrovnik", "Croatia", "Hırvatistan"]]],
	["LEG_AFRICA", [
		["Cairo", "Egypt", "Mısır"], ["Marrakesh", "Morocco", "Fas"], ["Tunis", "Tunisia", "Tunus"],
		["Dakar", "Senegal", "Senegal"], ["Lagos", "Nigeria", "Nijerya"], ["Accra", "Ghana", "Gana"],
		["Nairobi", "Kenya", "Kenya"], ["Zanzibar", "Tanzania", "Tanzanya"], ["Johannesburg", "South Africa", "Güney Afrika"],
		["Cape Town", "South Africa", "Güney Afrika"]]],
	["LEG_MIDDLE_EAST", [
		["Baku", "Azerbaijan", "Azerbaycan"], ["Tbilisi", "Georgia", "Gürcistan"], ["Yerevan", "Armenia", "Ermenistan"],
		["Amman", "Jordan", "Ürdün"], ["Riyadh", "Saudi Arabia", "Suudi Arabistan"], ["Doha", "Qatar", "Katar"],
		["Dubai", "United Arab Emirates", "Birleşik Arap Emirlikleri"], ["Muscat", "Oman", "Umman"],
		["Samarkand", "Uzbekistan", "Özbekistan"], ["Almaty", "Kazakhstan", "Kazakistan"]]],
	["LEG_SOUTH_ASIA", [
		["Karachi", "Pakistan", "Pakistan"], ["Delhi", "India", "Hindistan"], ["Jaipur", "India", "Hindistan"],
		["Mumbai", "India", "Hindistan"], ["Kathmandu", "Nepal", "Nepal"], ["Dhaka", "Bangladesh", "Bangladeş"],
		["Colombo", "Sri Lanka", "Sri Lanka"], ["Malé", "Maldives", "Maldivler"], ["Yangon", "Myanmar", "Myanmar"],
		["Bangkok", "Thailand", "Tayland"]]],
	["LEG_EAST_ASIA", [
		["Hanoi", "Vietnam", "Vietnam"], ["Singapore", "Singapore", "Singapur"], ["Kuala Lumpur", "Malaysia", "Malezya"],
		["Jakarta", "Indonesia", "Endonezya"], ["Manila", "Philippines", "Filipinler"], ["Hong Kong", "China", "Çin"],
		["Shanghai", "China", "Çin"], ["Beijing", "China", "Çin"], ["Seoul", "South Korea", "Güney Kore"],
		["Tokyo", "Japan", "Japonya"]]],
	["LEG_OCEANIA", [
		["Kyoto", "Japan", "Japonya"], ["Taipei", "Taiwan", "Tayvan"], ["Darwin", "Australia", "Avustralya"],
		["Brisbane", "Australia", "Avustralya"], ["Sydney", "Australia", "Avustralya"], ["Melbourne", "Australia", "Avustralya"],
		["Perth", "Australia", "Avustralya"], ["Auckland", "New Zealand", "Yeni Zelanda"],
		["Wellington", "New Zealand", "Yeni Zelanda"], ["Suva", "Fiji", "Fiji"]]],
	["LEG_AMERICAS_SOUTH", [
		["Santiago", "Chile", "Şili"], ["Buenos Aires", "Argentina", "Arjantin"], ["Montevideo", "Uruguay", "Uruguay"],
		["São Paulo", "Brazil", "Brezilya"], ["Rio de Janeiro", "Brazil", "Brezilya"], ["Lima", "Peru", "Peru"],
		["Cusco", "Peru", "Peru"], ["Quito", "Ecuador", "Ekvador"], ["Bogotá", "Colombia", "Kolombiya"],
		["Panama City", "Panama", "Panama"]]],
	["LEG_AMERICAS_NORTH", [
		["Havana", "Cuba", "Küba"], ["Mexico City", "Mexico", "Meksika"], ["Los Angeles", "United States", "ABD"],
		["San Francisco", "United States", "ABD"], ["Vancouver", "Canada", "Kanada"], ["Denver", "United States", "ABD"],
		["Chicago", "United States", "ABD"], ["Toronto", "Canada", "Kanada"], ["Montreal", "Canada", "Kanada"],
		["New York", "United States", "ABD"]]],
]


static func stop_count() -> int:
	return LEGS.size() * STOPS_PER_LEG


static func leg_of(level_index: int) -> int:
	return clampi(level_index, 0, stop_count() - 1) / STOPS_PER_LEG


static func leg_key(leg: int) -> String:
	return LEGS[clampi(leg, 0, LEGS.size() - 1)][0]


## [city, country] in the requested language ("tr" or anything else for English).
static func stop(level_index: int, language: String) -> PackedStringArray:
	var index := clampi(level_index, 0, stop_count() - 1)
	var entry: Array = LEGS[index / STOPS_PER_LEG][1][index % STOPS_PER_LEG]
	return PackedStringArray([entry[0], entry[2] if language == "tr" else entry[1]])


static func city(level_index: int, language: String) -> String:
	return stop(level_index, language)[0]
