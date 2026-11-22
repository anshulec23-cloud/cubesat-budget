function pw = power_budget(orb, gc, p)
%POWER_BUDGET Battery state of charge over the simulated day.
%   pw = POWER_BUDGET(orb, gc, p) integrates generated minus consumed power
%   into the battery. Panels produce p.solar_power_W in sunlight (assumes
%   Sun-pointing panels) and nothing in eclipse. Loads are a constant bus
%   load, the payload duty cycle, and the radio while in contact.

dt   = p.dt_s;
gen  = p.solar_power_W * ~orb.in_eclipse;

payload_on = mod(orb.t, orb.period_s) < p.payload_duty * orb.period_s;
load = p.bus_load_W ...
     + p.payload_load_W * payload_on ...
     + p.tx_load_W      * gc.visible;

cap_J  = p.battery_Wh * 3600;
E      = zeros(size(orb.t));
E(1)   = p.soc_initial * cap_J;
for k = 2:numel(orb.t)
    net = gen(k-1) - load(k-1);
    if net >= 0
        dE = net * dt * p.charge_eff;          % charging losses
    else
        dE = net * dt / p.discharge_eff;       % discharging losses
    end
    E(k) = min(max(E(k-1) + dE, 0), cap_J);
end
soc = E / cap_J;

orbit_avg_gen  = mean(gen);
orbit_avg_load = mean(load);

pw = struct('gen_W', gen, 'load_W', load, 'soc', soc, ...
            'min_soc', min(soc), 'max_dod', 1 - min(soc), ...
            'avg_gen_W', orbit_avg_gen, 'avg_load_W', orbit_avg_load, ...
            'margin_W', orbit_avg_gen - orbit_avg_load);
end
