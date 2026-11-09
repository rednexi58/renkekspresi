class_name WorldTour
extends RefCounted
## The campaign as a journey around the world, twice: twenty legs of ten stops, one city
## per level. Pure data, so the level map, the HUD and the win screen all name the same
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
	["LEG_MEDITERRANEAN", [
		["Antalya", "Türkiye", "Türkiye"], ["İzmir", "Türkiye", "Türkiye"], ["Thessaloniki", "Greece", "Yunanistan"],
		["Naples", "Italy", "İtalya"], ["Palermo", "Italy", "İtalya"], ["Valletta", "Malta", "Malta"],
		["Marseille", "France", "Fransa"], ["Nice", "France", "Fransa"], ["Valencia", "Spain", "İspanya"],
		["Seville", "Spain", "İspanya"]]],
	["LEG_ALPS_RHINE", [
		["Porto", "Portugal", "Portekiz"], ["Bordeaux", "France", "Fransa"], ["Geneva", "Switzerland", "İsviçre"],
		["Milan", "Italy", "İtalya"], ["Innsbruck", "Austria", "Avusturya"], ["Munich", "Germany", "Almanya"],
		["Salzburg", "Austria", "Avusturya"], ["Cologne", "Germany", "Almanya"], ["Luxembourg", "Luxembourg", "Lüksemburg"],
		["Hamburg", "Germany", "Almanya"]]],
	["LEG_BALTIC_NORDIC", [
		["Dublin", "Ireland", "İrlanda"], ["Cardiff", "United Kingdom", "Birleşik Krallık"], ["Bergen", "Norway", "Norveç"],
		["Gothenburg", "Sweden", "İsveç"], ["Tallinn", "Estonia", "Estonya"], ["Riga", "Latvia", "Letonya"],
		["Gdańsk", "Poland", "Polonya"], ["Tromsø", "Norway", "Norveç"], ["Rovaniemi", "Finland", "Finlandiya"],
		["Tórshavn", "Faroe Islands", "Faroe Adaları"]]],
	["LEG_BALKANS_BLACK_SEA", [
		["Ljubljana", "Slovenia", "Slovenya"], ["Zagreb", "Croatia", "Hırvatistan"], ["Sarajevo", "Bosnia and Herzegovina", "Bosna-Hersek"],
		["Podgorica", "Montenegro", "Karadağ"], ["Tirana", "Albania", "Arnavutluk"], ["Skopje", "North Macedonia", "Kuzey Makedonya"],
		["Varna", "Bulgaria", "Bulgaristan"], ["Constanța", "Romania", "Romanya"], ["Chișinău", "Moldova", "Moldova"],
		["Trabzon", "Türkiye", "Türkiye"]]],
	["LEG_SAHARA_SAVANNA", [
		["Casablanca", "Morocco", "Fas"], ["Fez", "Morocco", "Fas"], ["Algiers", "Algeria", "Cezayir"],
		["Luxor", "Egypt", "Mısır"], ["Khartoum", "Sudan", "Sudan"], ["Addis Ababa", "Ethiopia", "Etiyopya"],
		["Kampala", "Uganda", "Uganda"], ["Kigali", "Rwanda", "Ruanda"], ["Lusaka", "Zambia", "Zambiya"],
		["Windhoek", "Namibia", "Namibya"]]],
	["LEG_SILK_ROAD", [
		["Ankara", "Türkiye", "Türkiye"], ["Kars", "Türkiye", "Türkiye"], ["Tehran", "Iran", "İran"],
		["Isfahan", "Iran", "İran"], ["Ashgabat", "Turkmenistan", "Türkmenistan"], ["Bukhara", "Uzbekistan", "Özbekistan"],
		["Tashkent", "Uzbekistan", "Özbekistan"], ["Bishkek", "Kyrgyzstan", "Kırgızistan"], ["Astana", "Kazakhstan", "Kazakistan"],
		["Ulaanbaatar", "Mongolia", "Moğolistan"]]],
	["LEG_HIMALAYA_BAY", [
		["Lahore", "Pakistan", "Pakistan"], ["Amritsar", "India", "Hindistan"], ["Agra", "India", "Hindistan"],
		["Varanasi", "India", "Hindistan"], ["Kolkata", "India", "Hindistan"], ["Thimphu", "Bhutan", "Bhutan"],
		["Chennai", "India", "Hindistan"], ["Bengaluru", "India", "Hindistan"], ["Kochi", "India", "Hindistan"],
		["Chiang Mai", "Thailand", "Tayland"]]],
	["LEG_ISLANDS_ASIA", [
		["Phnom Penh", "Cambodia", "Kamboçya"], ["Vientiane", "Laos", "Laos"], ["Ho Chi Minh City", "Vietnam", "Vietnam"],
		["Bali", "Indonesia", "Endonezya"], ["Cebu", "Philippines", "Filipinler"], ["Macau", "China", "Çin"],
		["Guangzhou", "China", "Çin"], ["Chengdu", "China", "Çin"], ["Xi'an", "China", "Çin"],
		["Busan", "South Korea", "Güney Kore"]]],
	["LEG_JAPAN_PACIFIC", [
		["Osaka", "Japan", "Japonya"], ["Sapporo", "Japan", "Japonya"], ["Okinawa", "Japan", "Japonya"],
		["Guam", "United States", "ABD"], ["Port Moresby", "Papua New Guinea", "Papua Yeni Gine"], ["Cairns", "Australia", "Avustralya"],
		["Adelaide", "Australia", "Avustralya"], ["Hobart", "Australia", "Avustralya"], ["Queenstown", "New Zealand", "Yeni Zelanda"],
		["Honolulu", "United States", "ABD"]]],
	["LEG_AMERICAS_GRAND", [
		["Anchorage", "United States", "ABD"], ["Seattle", "United States", "ABD"], ["Calgary", "Canada", "Kanada"],
		["Las Vegas", "United States", "ABD"], ["Austin", "United States", "ABD"], ["New Orleans", "United States", "ABD"],
		["Miami", "United States", "ABD"], ["Washington", "United States", "ABD"], ["Boston", "United States", "ABD"],
		["Quebec City", "Canada", "Kanada"]]],
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
