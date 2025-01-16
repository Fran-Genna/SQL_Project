/* 1 TWH generati per anno
RISULTATO PREVISTO: TWH generati da ogni fonte, per ogni anno dal 2000 al 2020
Eseguo la somma dei Terawattora dalle varie fonti, rinnovabili e non, e li raggruppo per anno.*/
SELECT
    Year AS Anno, 
    SUM("Electricity from renewables (TWh)") AS TWH_da_rinnovabile,  
    SUM("Electricity from nuclear (TWh)") AS TWH_da_nucleare,
    SUM("Electricity from fossil fuels (TWh)") AS THW_da_combustibili_fossili, 
    SUM("Electricity from renewables (TWh)") + SUM("Electricity from nuclear (TWh)") AS TWH_da_rinnovabili_e_nucleare,  
    SUM("Electricity from renewables (TWh)") + SUM("Electricity from nuclear (TWh)") + SUM("Electricity from fossil fuels (TWh)") AS TWH_Totali 
FROM Global_sustainability  
GROUP BY Year
ORDER BY Year;







/* 2 Leader nella produzione elettrica green.
RISULTATO PREVISTO: I 10 paesi che hanno generato più elettricità da fonti rinnovabili, 
la quantità di TWH, e la percentuale sulla quantità di TWH globali.

Creo una CTE calcola il totale di elettricità generato da fonti rinnovabile (in TWh) 
raggruppandolo per paese */
WITH classifica_elettricita_rinnovabile AS (
    SELECT
        Entity AS Paese, 
        SUM("Electricity from renewables (TWh)") AS totale_elettricita_rinnovabile 
    FROM Global_sustainability
    GROUP BY Entity 
),

/* La seconda CTE calcola il totale globale di elettricità rinnovabile.
Il dato mi servirà nella query seguente per il calcolo della percentuale*/
totale_elettricita_globale AS (
    SELECT
        SUM("Electricity from renewables (TWh)") AS totale_elettricita_mondiale 
    FROM Global_sustainability
)

/* La query seguente unisce i dati delle due precedenti CTE e calcola
la percentuale dell'elettricità rinnovabile prodotta da ciascun paese sul totale mondiale */
SELECT
    er.Paese, 
    er.totale_elettricita_rinnovabile, 
    ROUND((er.totale_elettricita_rinnovabile / tg.totale_elettricita_mondiale) * 100, 2) AS percentuale_elettricita_rinnovabile 
FROM classifica_elettricita_rinnovabile er --Prima CTE
CROSS JOIN totale_elettricita_globale tg --Seconda CTE
WHERE er.totale_elettricita_rinnovabile IS NOT NULL 
ORDER BY er.totale_elettricita_rinnovabile DESC -- Per ordinare secondo i paesi che hanno prodotto più elettricità green
LIMIT 10;








/* 3 I leader green e le loro emissioni
RISULTATO PREVISTO: I paesi che hanno generato più TWH da fonti green negli ultimi 20 anni, 
					le loro emissioni di Co2 nel 2023, e la percentuale sulle emissioni di CO2 totali.*/

--La prima CTE somma le emissioni
WITH emissioni_totali_co2 AS (
    SELECT
        SUM("Co2-Emissions") AS co2_globale /* Questo valore sarà utilizzato per calcolare la percentuale
   												delle emissioni di ciascun paese sul totale globale */
    FROM World_data_2023
),
/* La seguente CTE seleziona i paesi in base
alla produzione di energia rinnovabile, e le classifica tramite Ranking */
paesi_selezionati AS (
    SELECT
        er.Paese,
        er.posizione_energia_rinnovabile
    FROM -- SUBQUERY
        	(SELECT
               	Entity AS Paese,
               	DENSE_RANK() OVER (ORDER BY SUM("Electricity from renewables (TWh)") DESC) AS posizione_energia_rinnovabile
            FROM Global_sustainability
            WHERE "Electricity from renewables (TWh)" IS NOT NULL
            GROUP BY Entity) er 
			/* da 'er' estrapoliamo Paese e 
			il ranking (colonna 'posizione_energia_rinnovabile'), dati che ci servono per popolare
			la CTE 'paesi_selezionati' */
    WHERE
        er.posizione_energia_rinnovabile <= 10 
)
/* Seleziono le colonne d'interesse, unendo le CTE */
SELECT
    ps.Paese,
    ps.posizione_energia_rinnovabile,
    wd."Co2-Emissions" AS emissioni_co2_paese,
    et.co2_globale AS emissioni_co2_globali,
    ROUND((wd."Co2-Emissions" / et.co2_globale) * 100, 2) AS Percentuale_co2_suTotale
FROM paesi_selezionati ps
JOIN World_data_2023 wd
ON ps.Paese = wd.Country
CROSS JOIN emissioni_totali_co2 et
ORDER BY ps.posizione_energia_rinnovabile ASC;












/* 4 Paesi leader - NUCLEARE
RISULTATO PREVISTO: I 10 paesi con maggior produzione di energia nucleare negli ultimi 20 anni,
					TWH prodotti nel 2000 e 2020*/
-- La CTE considera la produzione di energia nucleare nel 2000 e 2020.
WITH crescita_produzione_nucleare AS (
    SELECT
        Entity AS Paese, 
        "Electricity from nuclear (TWh)" AS energia_nucleare,  
        Year 
    FROM Global_sustainability 
    WHERE Year IN (2000, 2020)  
)

-- Selezione dei dati cercati
SELECT
    cpn_2020.Paese,  
    cpn_2000.energia_nucleare AS energia_nucleare_2000,  
    cpn_2020.energia_nucleare AS energia_nucleare_2020,
    cpn_2020.energia_nucleare - cpn_2000.energia_nucleare AS crescita_produzione_nucleare
FROM crescita_produzione_nucleare cpn_2000  
JOIN crescita_produzione_nucleare cpn_2020   /*Le tabelle cpn_2020 e cpn_2000 vengono implicitamente create 
												all'interno della CTE 'crescita_produzione_nucleare' */
    ON cpn_2000.Paese = cpn_2020.Paese  
    AND cpn_2000.Year = 2000  
    AND cpn_2020.Year = 2020  
WHERE cpn_2000.energia_nucleare > 0  
ORDER BY crescita_produzione_nucleare DESC  
LIMIT 10;  








/* 5 Paesi sviluppati e nucleare.
RISULTATO PREVISTO: I 10 paesi più sviluppati (PIL più alto nel 2023) ed i TWH totale generati da fonti nucleari nel 2000 e 2020*/

--Con la prima CTE, si selezionano i paesi con Pil più alto e assegno il rank
WITH classifica_pil AS (
    SELECT
        Country AS Paese,
        RANK() OVER (ORDER BY GDP DESC) AS posizione_pil
    FROM World_data_2023
    WHERE GDP IS NOT NULL
),
-- Identificazione del primo anno con energia nucleare registrata per ciascun paese
primo_anno_energia AS (
    SELECT
        Entity AS Paese,
        MIN(Year) AS primo_anno
    FROM Global_sustainability
    WHERE "Electricity from nuclear (TWh)" IS NOT NULL
    GROUP BY Entity
),
-- Recupero i dati per il 2020 e per il primo anno senza aggregazioni
energia_nucleare_anni AS (
    SELECT
        g.Entity AS Paese,
        g.Year,
        g."Electricity from nuclear (TWh)" AS energia_nucleare
    FROM Global_sustainability g
    WHERE g.Year = 2020 OR g.Year IN (
        SELECT MIN(Year)
        FROM Global_sustainability
        WHERE "Electricity from nuclear (TWh)" IS NOT NULL
        GROUP BY Entity
    )
),
-- Unione dei dati del primo anno e del 2020
sviluppo_nucleare AS (
    SELECT
        e2020.Paese,
        eprimo.energia_nucleare AS energia_nucleare_primo_anno,
        e2020.energia_nucleare AS energia_nucleare_2020,
        e2020.energia_nucleare - eprimo.energia_nucleare AS crescita_nucleare
    FROM energia_nucleare_anni eprimo
    JOIN energia_nucleare_anni e2020
        ON eprimo.Paese = e2020.Paese
    JOIN primo_anno_energia p
        ON eprimo.Paese = p.Paese AND eprimo.Year = p.primo_anno
    WHERE e2020.Year = 2020
)
-- Unione i dati di PIL con quelli sul nucleare
SELECT
    cp.Paese,
    sn.energia_nucleare_primo_anno AS energia_nucleare_primo_anno,
    sn.energia_nucleare_2020 AS energia_nucleare_2020,
    sn.crescita_nucleare AS crescita_nucleare
FROM classifica_pil cp
LEFT JOIN sviluppo_nucleare sn
    ON cp.Paese = sn.Paese
WHERE sn.energia_nucleare_primo_anno IS NOT NULL
    AND sn.energia_nucleare_2020 IS NOT NULL
ORDER BY cp.posizione_pil ASC
LIMIT 10;





-- 6 Efficacia finanziamenti- 
/* RISULTATO PREVISTO: I 10 Paesi più finanziati, ed i TWH da fonti rinnovabili e da combustibili fossili nel 2000 e 2020.
La prima CTE calcola il totale dei flussi finanziari (in dollari USA) per paese */
WITH FlussiFinanziari AS (
    SELECT 
        entity AS paese, 
        SUM("Financial flows to developing countries (US $)") AS totale_flussi
    FROM global_sustainability
    WHERE "Financial flows to developing countries (US $)" IS NOT NULL
          AND "Financial flows to developing countries (US $)" != 0
    GROUP BY entity
),

-- Identifico il primo anno con valori registrati di elettricità da fonti rinnovabili
PrimoAnnoElettricita AS (
    SELECT 
        entity AS paese, 
        MIN(Year) AS primo_anno_elettricita
    FROM global_sustainability
    WHERE "Electricity from renewables (TWh)" IS NOT NULL
          OR "Electricity from fossil fuels (TWh)" IS NOT NULL
    GROUP BY entity
),

-- Recupero i valori di elettricità da fonti rinnovabili e fossili al primo anno e nel 2020
ValoriElettricita AS (
    SELECT 
        g.entity AS paese, 
        MAX(CASE WHEN g.Year = p.primo_anno_elettricita THEN g."Electricity from renewables (TWh)" END) AS elettricita_rinnovabili_primo_anno,
        MAX(CASE WHEN g.Year = 2020 THEN g."Electricity from renewables (TWh)" END) AS elettricita_rinnovabili_2020,
        MAX(CASE WHEN g.Year = p.primo_anno_elettricita THEN g."Electricity from fossil fuels (TWh)" END) AS elettricita_fossili_primo_anno,
        MAX(CASE WHEN g.Year = 2020 THEN g."Electricity from fossil fuels (TWh)" END) AS elettricita_fossili_2020
    FROM global_sustainability g
    INNER JOIN PrimoAnnoElettricita p 
        ON g.entity = p.paese
    WHERE g."Electricity from renewables (TWh)" IS NOT NULL
          OR g."Electricity from fossil fuels (TWh)" IS NOT NULL
    GROUP BY g.entity, p.primo_anno_elettricita
)

-- Query finale
SELECT 
    r.paese,
    RANK() OVER (ORDER BY r.totale_flussi DESC) AS ranking_flussi_finanziari,
    ve.elettricita_rinnovabili_primo_anno,
    ve.elettricita_rinnovabili_2020,
    ve.elettricita_fossili_primo_anno,
    ve.elettricita_fossili_2020
FROM FlussiFinanziari r
LEFT JOIN ValoriElettricita ve ON r.paese = ve.paese
ORDER BY ranking_flussi_finanziari
LIMIT 10;



/* 7 Capacità di generazione energia innovabile pro capite
RISULTATO PREVISTO : I 10 paesi più finanziati, la loro capacità di generazione energia innovabile pro capite nel 2000 e 2020.
Come in precedenza, si selezionano i paesi più finanziati */
WITH FlussiFinanziari AS (
    SELECT
        entity AS paese, 
        RANK() OVER (ORDER BY SUM("Financial flows to developing countries (US $)") DESC) AS ranking_flussi_finanziari
    FROM global_sustainability
    WHERE "Financial flows to developing countries (US $)" IS NOT NULL
    GROUP BY entity 
),

-- Recupero dei valori di capacità rinnovabile per capita per gli anni 2000 e 2020
CapacitaRinnovabile AS (
    SELECT 
        entity AS paese, 
        MAX(CASE WHEN year = 2000 THEN "Renewable-electricity-generating-capacity-per-capita" END) AS capacita_2000, 
        MAX(CASE WHEN year = 2020 THEN "Renewable-electricity-generating-capacity-per-capita" END) AS capacita_2020
    FROM global_sustainability
    WHERE "Renewable-electricity-generating-capacity-per-capita" IS NOT NULL
    GROUP BY entity 
)

-- Query finale per selezionare i dati cercati
SELECT 
    f.paese, 
    f.ranking_flussi_finanziari, 
    cr.capacita_2000 AS capacita_rinnovabile_2000, 
    cr.capacita_2020 AS capacita_rinnovabile_2020
FROM FlussiFinanziari f
LEFT JOIN CapacitaRinnovabile cr
    ON f.paese = cr.paese
ORDER BY f.ranking_flussi_finanziari 
LIMIT 10;


