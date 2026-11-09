class_name Season
extends RefCounted
## Seasons along the campaign: five summer stops, then five winter stops, and so on, so
## the look and the music change regularly without a level ever switching mid-play.
## Winter uses the snow scenery (theme 5); a summer level never gets the snow theme.

enum Kind { SUMMER, WINTER }

const STOPS_PER_SEASON := 5
const SNOW_THEME := 5
const SUMMER_FALLBACK_THEME := 0


static func of(level_index: int) -> Kind:
	return Kind.WINTER if (maxi(level_index, 0) / STOPS_PER_SEASON) % 2 == 1 else Kind.SUMMER


static func is_winter(level_index: int) -> bool:
	return of(level_index) == Kind.WINTER


## Scenery theme actually shown for a level: snow in winter, its own theme in summer.
static func theme_for(level: LevelDefinition) -> int:
	if is_winter(level.id - 1):
		return SNOW_THEME
	return SUMMER_FALLBACK_THEME if level.theme == SNOW_THEME else level.theme
