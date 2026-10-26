-- Testes da lógica pura de src/shared. Rodar com: python3 tests/run.py
-- Os valores conferem com as tabelas do GDD (Economia e faixas).

local function eq(a,b,msg) if a~=b then error(msg..": esperado "..tostring(b).." obtido "..tostring(a)) end end
eq(AuraMath.getBand(0).name,"Spark","banda 0")
eq(AuraMath.getBand(999).name,"Spark","banda 999")
eq(AuraMath.getBand(1000).name,"Glow","banda 1000")
eq(AuraMath.getBand(2e8).name,"Sigma Supreme","banda max")
eq(AuraMath.getNextBand(2e8),nil,"sem proxima")
eq(math.floor(AuraMath.generatorRate(10)),41,"taxa nv10")
eq(math.floor(AuraMath.generatorRate(20)),1195,"taxa nv20")
eq(math.floor(AuraMath.generatorRate(30)),34573,"taxa nv30")
eq(AuraMath.upgradeCost(1),50,"custo nv1")
eq(AuraMath.upgradeCost(10),3436,"custo nv10")
eq(AuraMath.upgradeCost(20),377789,"custo nv20")
eq(AuraMath.upgradeCost(30),nil,"custo nv max")
eq(AuraMath.multiplier(2),1.5,"mult 2 rebirths")
eq(AuraMath.offlineGain(100, 10*3600),180000,"offline cap 2h")
local c,v = AuraMath.splitCollect(100,false) eq(c,80,"carregada") eq(v,20,"cofre")
c,v = AuraMath.splitCollect(100,true) eq(v,50,"cofre+")
eq(Format.short(999),"999","fmt") eq(Format.short(1234),"1.23K","fmt K") eq(Format.short(5e6),"5M","fmt M") eq(Format.short(1e9+5e7),"1.05B","fmt B") eq(Format.short(100000),"100K","fmt 100K")
eq(AuraMath.hasBeginnerShield(14),true,"escudo 14 min") eq(AuraMath.hasBeginnerShield(15),false,"escudo 15 min")
eq(#Powers.list,12,"12 poderes no MVP")
local seenBands = {}
for _, p in Powers.list do
	eq(Powers.byId[p.id],p,"id unico "..p.id)
	eq(p.shotCost,Bands[p.band].shotCost,"custo por disparo = faixa "..p.name)
	assert(Powers.rarityColors[p.rarity],"cor da raridade "..p.rarity)
	seenBands[p.band] = true
end
for band = 1, 6 do assert(seenBands[band],"faixa sem poder novo: "..band) end
eq(Powers.byId["28"].price,15000000,"preco Aura Thief")
eq(Format.rate(2),"2","taxa 2") eq(Format.rate(2.8),"2.8","taxa 2.8") eq(Format.rate(3.92),"3.9","taxa 3.92") eq(Format.rate(41.3),"41.3","taxa 41.3") eq(Format.rate(1195.6),"1.2K","taxa 1195")
-- Poderes: uso pela faixa, treino, roubo e um modelo de comportamento para cada poder.
local punch, voidOrb, thief = Powers.byId["1"], Powers.byId["14"], Powers.byId["28"]
eq(PowerMath.isUsable(voidOrb, 2),false,"Void Orb na faixa 2") eq(PowerMath.isUsable(voidOrb, 3),true,"Void Orb na faixa 3")
eq(PowerMath.damage(punch, 1),10,"dano nv1") eq(PowerMath.damage(punch, 5),14,"dano nv5 +40%")
eq(PowerMath.damage(Powers.byId["5"], 2),13.2,"Static Ray nv2")
eq(PowerMath.trainCost(punch, 1),300,"treino 1->2") eq(PowerMath.trainCost(punch, 4),1200,"treino 4->5") eq(PowerMath.trainCost(punch, 5),nil,"treino nv max")
eq(PowerMath.stealPct(punch),0.25,"roubo comum") eq(PowerMath.stealPct(voidOrb),0.30,"roubo raro") eq(PowerMath.stealPct(thief),0.50,"roubo lendario")
for _, p in Powers.list do assert(Arena.Models[p.model],"modelo sem config: "..p.model) end
eq(Arena.MaxEquipped,3,"3 equipados")
print("todos os testes passaram")

