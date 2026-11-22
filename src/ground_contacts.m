function gc = ground_contacts(orb, p)
%GROUND_CONTACTS Elevation, slant range and passes over a ground station.
%   gc = GROUND_CONTACTS(orb, p) computes the satellite elevation angle and
%   slant range seen from the ground station at p.gs_lat_deg, p.gs_lon_deg,
%   and splits the time series into passes above p.min_elevation_deg.

Re  = orb.Re;
lat = deg2rad(p.gs_lat_deg);
lon = deg2rad(p.gs_lon_deg);
r_gs = Re * [cos(lat)*cos(lon), cos(lat)*sin(lon), sin(lat)];
up   = r_gs / norm(r_gs);

rho   = orb.r_ecef - r_gs;                       % station-to-satellite
range = sqrt(sum(rho.^2, 2));
elev  = rad2deg(asin((rho * up') ./ range));

visible = elev >= p.min_elevation_deg;

% Find pass start/end indices from rising/falling edges
d      = diff([0; visible; 0]);
starts = find(d == 1);
ends   = find(d == -1) - 1;

passes = struct('t_start', {}, 't_end', {}, 'duration_s', {}, 'max_elev_deg', {});
for k = 1:numel(starts)
    idx = starts(k):ends(k);
    passes(k).t_start      = orb.t(starts(k));
    passes(k).t_end        = orb.t(ends(k));
    passes(k).duration_s   = orb.t(ends(k)) - orb.t(starts(k)) + p.dt_s;
    passes(k).max_elev_deg = max(elev(idx));
end

gc = struct('elev_deg', elev, 'range_m', range, 'visible', visible, ...
            'passes', passes);
end
