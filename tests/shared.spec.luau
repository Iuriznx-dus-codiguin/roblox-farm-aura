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
eq(Format.rate(2),"2","taxa 2") eq(Format.rate(2.8),"2.8","taxa 2.8") eq(Format.rate(3.92),"3.9","taxa 3.92") eq(Format.rate(41.3),"41.3","taxa 41.3") eq(Format.rate(1195.6),"1.2K","taxa 1195")
print("todos os testes passaram")

