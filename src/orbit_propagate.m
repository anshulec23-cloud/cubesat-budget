function orb = orbit_propagate(p)
%ORBIT_PROPAGATE Two-body circular orbit propagation with Earth rotation.
%   orb = ORBIT_PROPAGATE(p) propagates a circular orbit for p.duration_s
%   seconds at a fixed time step and returns satellite positions in the
%   inertial (ECI) and Earth-fixed (ECEF) frames, the ground track, and the
%   eclipse flag from a cylindrical Earth-shadow model.
%
%   Assumptions: circular orbit, spherical Earth, no J2 or drag, Sun
%   direction fixed in ECI over the simulated day.

mu  = 3.986004418e14;          % Earth gravitational parameter [m^3/s^2]
Re  = 6378137;                 % Earth equatorial radius [m]
wE  = 7.2921159e-5;            % Earth rotation rate [rad/s]

a   = Re + p.altitude_m;
n   = sqrt(mu / a^3);          % mean motion [rad/s]
T   = 2*pi / n;                % orbital period [s]

t   = (0:p.dt_s:p.duration_s)';
i   = deg2rad(p.inclination_deg);
raan = deg2rad(p.raan_deg);
u   = n * t;                   % argument of latitude (circular orbit)

% Position in ECI
x = a * (cos(raan).*cos(u) - sin(raan).*sin(u).*cos(i));
y = a * (sin(raan).*cos(u) + cos(raan).*sin(u).*cos(i));
z = a * (sin(u).*sin(i));
r_eci = [x y z];

% Rotate into ECEF
th = wE * t;
xe =  cos(th).*x + sin(th).*y;
ye = -sin(th).*x + cos(th).*y;
r_ecef = [xe ye z];

lat = rad2deg(asin(z ./ a));
lon = rad2deg(atan2(ye, xe));

% Sun direction (fixed in ECI) and beta angle
s = p.sun_dir_eci(:)' / norm(p.sun_dir_eci);
h_hat = [sin(raan)*sin(i), -cos(raan)*sin(i), cos(i)];   % orbit normal
beta = asin(dot(h_hat, s));

% Cylindrical shadow: behind Earth and inside the shadow cylinder
along = r_eci * s';
perp  = sqrt(sum(r_eci.^2, 2) - along.^2);
in_eclipse = (along < 0) & (perp < Re);

orb = struct('t', t, 'r_eci', r_eci, 'r_ecef', r_ecef, 'lat', lat, ...
             'lon', lon, 'in_eclipse', in_eclipse, 'period_s', T, ...
             'a_m', a, 'beta_rad', beta, 'Re', Re);
end
