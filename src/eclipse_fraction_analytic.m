function f = eclipse_fraction_analytic(altitude_m, beta_rad, Re)
%ECLIPSE_FRACTION_ANALYTIC Fraction of a circular orbit spent in eclipse.
%   f = ECLIPSE_FRACTION_ANALYTIC(h, beta, Re) uses the cylindrical-shadow
%   closed form. Used to cross-check the simulated eclipse fraction.

a = Re + altitude_m;
beta_star = asin(Re / a);            % beta above which there is no eclipse
if abs(beta_rad) >= beta_star
    f = 0;
else
    f = acos(sqrt(altitude_m^2 + 2*Re*altitude_m) / (a * cos(beta_rad))) / pi;
end
end
