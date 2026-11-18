extends Reference
func reset_cache():
 pass
func build_wave_groups(_wave):
 return {"groups":[],"duration":60.0,"partial":false}
func simulate(_groups,_duration,_wave,_flags):
 return {"total_hp":600.0,"enemies":50.0,"boss_hp":0.0,"materials":80.0}
