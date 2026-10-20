shader_type canvas_item;
// Political map from a province-ID raster.
// id_map:  RG8, province id = R + G * 256 (0 = sea), nearest sampled.
// palette: 256x256, texel (id % 256, id / 256) holds the province's fill colour
//          in RGB and its owner's country index (+1) in A; A = 255 marks a
//          wasteland (impassable, drawn hatched), A = 254 a sea tile. Id 0 is
//          water without a tile (small lakes).
// stripes: 256x256 like the palette; A > 0 draws diagonal stripes of the RGB
//          colour over the province, A being the stripe's share of each period
//          (occupation: the occupier's or the owner's colour).
// selected_country: palette A value (country index + 1) of the country whose
//          territory is highlighted and outlined; 0 = none.
// height_map: RG8, R = relief (< 0.5 sea depth, >= 0.5 land height). Rivers
//             are drawn separately as vector lines (MapRivers).
// The map wraps east-west, so x lookups wrap and the relief texture repeats.
//
// Two border paths:
//  - zoomed out (a screen pixel covers 0.55+ map pixels): borders found by
//    comparing ids a fixed number of screen pixels away;
//  - zoomed in: the four id texels around the point vote with bilinear
//    weights. That turns the texel staircase into smooth curves and gives a
//    distance to the edge in screen pixels, so borders are anti-aliased lines
//    of constant width at any zoom.
render_mode unshaded;

uniform sampler2D id_map : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D stripes : filter_nearest, repeat_disable;
uniform sampler2D height_map : filter_linear, repeat_enable;
uniform vec2 map_size = vec2(1600.0, 1000.0);
uniform int selected_id = 0;
uniform int selected_country = 0;
uniform float relief_strength = 14.0;
uniform vec3 sea_shallow : source_color = vec3(0.24, 0.40, 0.50);
uniform vec3 sea_deep : source_color = vec3(0.12, 0.21, 0.31);
uniform vec4 province_border : source_color = vec4(0.06, 0.05, 0.04, 0.30);
uniform vec4 country_border : source_color = vec4(0.10, 0.07, 0.05, 0.90);
uniform vec4 coast_line : source_color = vec4(0.12, 0.15, 0.17, 0.85);
uniform vec3 selection : source_color = vec3(1.0, 0.86, 0.35);
uniform vec4 sea_border : source_color = vec4(0.62, 0.74, 0.80, 0.30);

int fetch_id(vec2 px) {
	px.x = mod(px.x, map_size.x);
	ivec2 p = clamp(ivec2(floor(px)), ivec2(0), ivec2(map_size) - ivec2(1));
	vec4 c = texelFetch(id_map, p, 0);
	return int(round(c.r * 255.0)) + int(round(c.g * 255.0)) * 256;
}

vec4 palette_entry(int id) {
	return texelFetch(palette, ivec2(id % 256, id / 256), 0);
}

int owner_of(int id) {
	return int(round(palette_entry(id).a * 255.0));
}

bool is_water(int id) {
	return id == 0 || owner_of(id) == 254;
}

bool any_differs(vec2 px, vec2 o, int id) {
	return fetch_id(px + vec2(o.x, 0.0)) != id || fetch_id(px - vec2(o.x, 0.0)) != id
		|| fetch_id(px + vec2(0.0, o.y)) != id || fetch_id(px - vec2(0.0, o.y)) != id;
}

bool touches_sea(vec2 px, vec2 o) {
	return is_water(fetch_id(px + vec2(o.x, 0.0))) || is_water(fetch_id(px - vec2(o.x, 0.0)))
		|| is_water(fetch_id(px + vec2(0.0, o.y))) || is_water(fetch_id(px - vec2(0.0, o.y)));
}

bool touches_land(vec2 px, vec2 o) {
	return !is_water(fetch_id(px + vec2(o.x, 0.0))) || !is_water(fetch_id(px - vec2(o.x, 0.0)))
		|| !is_water(fetch_id(px + vec2(0.0, o.y))) || !is_water(fetch_id(px - vec2(0.0, o.y)));
}

bool other_country(int n, int owner) {
	return !is_water(n) && owner_of(n) != owner;
}

// True if a neighbour a given offset away is not land of `country`.
bool country_border_near(vec2 px, vec2 o, int country) {
	return owner_of(fetch_id(px + vec2(o.x, 0.0))) != country || owner_of(fetch_id(px - vec2(o.x, 0.0))) != country
		|| owner_of(fetch_id(px + vec2(0.0, o.y))) != country || owner_of(fetch_id(px - vec2(0.0, o.y))) != country;
}

float weight_of(int id, int a, int b, int c, int d, vec4 w) {
	return (a == id ? w.x : 0.0) + (b == id ? w.y : 0.0) + (c == id ? w.z : 0.0) + (d == id ? w.w : 0.0);
}

// Smooth lookup: the id with the largest bilinear weight among the 2x2 texels,
// the runner-up id, and the weight margin between them (0 on the edge).
void smooth_ids(vec2 px, out int main_id, out int other_id, out float margin) {
	vec2 q = px - 0.5;
	vec2 f = fract(q);
	vec2 b = floor(q) + 0.5;
	int a = fetch_id(b);
	int bb = fetch_id(b + vec2(1.0, 0.0));
	int c = fetch_id(b + vec2(0.0, 1.0));
	int d = fetch_id(b + vec2(1.0, 1.0));
	vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
	float wa = weight_of(a, a, bb, c, d, w);
	float wb = weight_of(bb, a, bb, c, d, w);
	float wc = weight_of(c, a, bb, c, d, w);
	float wd = weight_of(d, a, bb, c, d, w);
	main_id = a;
	float best = wa;
	if (wb > best) { main_id = bb; best = wb; }
	if (wc > best) { main_id = c; best = wc; }
	if (wd > best) { main_id = d; best = wd; }
	other_id = main_id;
	float second = 0.0;
	if (a != main_id && wa > second) { other_id = a; second = wa; }
	if (bb != main_id && wb > second) { other_id = bb; second = wb; }
	if (c != main_id && wc > second) { other_id = c; second = wc; }
	if (d != main_id && wd > second) { other_id = d; second = wd; }
	margin = best - second;
}

vec3 fill_color(int id, vec2 px, vec2 spx, float h, float shade) {
	if (is_water(id)) {
		float depth = clamp((0.5 - h) * 6.0, 0.0, 1.0);
		return mix(sea_shallow, sea_deep, smoothstep(0.0, 1.0, depth));
	}
	float light = 0.68 + 0.48 * shade;
	vec4 entry = palette_entry(id);
	vec3 col = entry.rgb * light;
	int owner = int(round(entry.a * 255.0));
	if (owner == 255) {
		// Wasteland: diagonal hatching, about 7 screen pixels apart.
		float band = fract((px.x + px.y) / (spx.x * 7.0));
		col *= mix(1.0, 0.82, step(0.55, band));
		return col;
	}
	vec4 stripe = texelFetch(stripes, ivec2(id % 256, id / 256), 0);
	if (stripe.a > 0.0) {
		// Occupation: stripes along the other diagonal, 9 screen pixels apart,
		// anti-aliased on both edges.
		float t = abs(fract((px.x - px.y) / (spx.x * 9.0)) - 0.5) * 9.0;
		float half_stripe = stripe.a * 4.5;
		col = mix(col, stripe.rgb * light, 1.0 - smoothstep(half_stripe - 0.6, half_stripe + 0.6, t));
	}
	if (selected_country > 0 && owner == selected_country) {
		col = mix(col, vec3(1.0), 0.14);
	}
	return col;
}

void fragment() {
	vec2 px = UV * map_size;
	// Map pixels per screen pixel: keeps border widths constant on screen.
	vec2 spx = max(fwidth(px), vec2(1e-4));

	vec2 t = 1.0 / map_size;
	vec2 relief = texture(height_map, UV).rg;
	float h = relief.r;
	float dx = texture(height_map, UV + vec2(t.x, 0.0)).r - texture(height_map, UV - vec2(t.x, 0.0)).r;
	float dy = texture(height_map, UV + vec2(0.0, t.y)).r - texture(height_map, UV - vec2(0.0, t.y)).r;
	vec3 n = normalize(vec3(-dx * relief_strength, -dy * relief_strength, 1.0));
	float shade = clamp(dot(n, normalize(vec3(-0.6, -0.7, 0.8))), 0.0, 1.0);

	vec3 col;
	if (spx.x < 0.55) {
		int id;
		int other;
		float margin;
		smooth_ids(px, id, other, margin);
		col = fill_color(id, px, spx, h, shade);
		if (id != 0 && id == selected_id) {
			col = mix(col, vec3(1.0), 0.16);
		}
		if (other != id) {
			// Screen-pixel distance to the edge between the two provinces.
			float grad = length(vec2(dFdx(margin), dFdy(margin)));
			float dist = margin / max(grad, 1e-5);
			bool water_here = is_water(id);
			bool water_there = is_water(other);
			bool coast = water_here != water_there;
			bool sea_edge = water_here && water_there;
			bool country = !coast && !sea_edge && owner_of(id) != owner_of(other);
			float half_width = coast ? 0.9 : (country ? 1.5 : 0.6);
			vec4 line = coast ? coast_line : (sea_edge ? sea_border : (country ? country_border : province_border));
			col = mix(col, line.rgb, line.a * (1.0 - smoothstep(half_width - 0.6, half_width + 0.6, dist)));
			if (selected_country > 0 && (owner_of(id) == selected_country) != (owner_of(other) == selected_country)) {
				col = mix(col, selection, 0.9 * (1.0 - smoothstep(1.2, 2.0, dist)));
			}
			if (selected_id > 0 && (id == selected_id || other == selected_id)) {
				col = mix(col, selection, 1.0 - smoothstep(1.8, 2.8, dist));
			}
		}
	} else {
		int id = fetch_id(px);
		col = fill_color(id, px, spx, h, shade);
		if (is_water(id)) {
			// Faint lines between sea tiles, fading out when zoomed far out.
			if (id != 0 && any_differs(px, spx * 0.6, id) && !touches_land(px, spx * 0.6)) {
				float fade = clamp((3.0 - spx.x) / 1.5, 0.0, 1.0);
				col = mix(col, sea_border.rgb, sea_border.a * fade);
			}
			if (id != 0 && id == selected_id && any_differs(px, spx * 2.6, id)) {
				col = selection;
			}
		} else {
			if (id == selected_id) {
				col = mix(col, vec3(1.0), 0.16);
			}
			vec2 o1 = spx * 0.6;
			vec2 o2 = spx * 1.4;
			if (any_differs(px, o2, id)) {
				int owner = owner_of(id);
				bool country_edge = other_country(fetch_id(px + vec2(o2.x, 0.0)), owner)
					|| other_country(fetch_id(px - vec2(o2.x, 0.0)), owner)
					|| other_country(fetch_id(px + vec2(0.0, o2.y)), owner)
					|| other_country(fetch_id(px - vec2(0.0, o2.y)), owner);
				if (touches_sea(px, spx)) {
					col = mix(col, coast_line.rgb, coast_line.a);
				} else if (country_edge) {
					col = mix(col, country_border.rgb, country_border.a);
				} else if (any_differs(px, o1, id)) {
					// Province borders fade out when zoomed far out, leaving country borders.
					float fade = clamp((3.2 - spx.x) / 1.6, 0.0, 1.0);
					col = mix(col, province_border.rgb, province_border.a * fade);
				}
			}
			if (id == selected_id && any_differs(px, spx * 2.6, id)) {
				col = selection;
			}
			if (selected_country > 0 && owner_of(id) == selected_country && country_border_near(px, spx * 1.6, selected_country)) {
				col = mix(col, selection, 0.9);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
