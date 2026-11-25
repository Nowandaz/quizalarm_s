# Brief: extracting revision questions from PDFs for Brain O' Clock

Give this whole document to the assistant, then attach the PDFs. The JSON files it produces come back
to the main session, which checks them and loads them into the app's question bank.

---

You are helping build the question bank of **Brain O' Clock**, a revision app for medical students
(University of Nairobi, MBChB, Clinical Pharmacology). The app wakes students with an alarm that only
stops when they answer questions, and also lets them practise. I will attach PDFs of questions. Turn
every usable question in them into an entry in the format below.

## Before you start: which PDFs are allowed

Only work from material the student is entitled to use: **past exam papers and CATs, and question
sets written or compiled by lecturers or classmates**. Do NOT extract from published commercial books
or question banks (PreTest, Rang & Dale flash cards, Rapid Review, USMLE prep books, BRS, Lippincott
and the like): copying those into a paid app is copyright infringement. If a PDF is one of those, say
so and stop. (Writing brand-new questions of your own on the same facts is fine, if asked.)

## How to work through a PDF

- Go through EVERY page in order. Do not sample and do not stop early. For a long PDF, work in batches
  of about 30 to 40 pages and write one JSON file per batch, so nothing is lost and no batch is rushed.
  Say clearly which pages each file covers.
- Scanned or photographed pages: read the page image itself. Do not trust a rough text layer for drug
  names, numbers or options.
- Cover pages, contents lists, blank answer boxes and instructions carry no question: skip them.
- A question may start on one page and finish on the next: join the two.
- **Never copy a marked answer as the truth.** A ticked option, a highlighted line or a handwritten
  answer is only what one student chose, and answer keys in these compilations are often wrong. Work
  out the correct answer yourself from sound pharmacology (Katzung, Rang & Dale, Goodman & Gilman, BNF,
  WHO and Kenyan guidelines). Where the paper's answer disagrees with yours, go with what is
  pharmacologically correct and say so in `note`.
- Some questions are carelessly written (two right options, no right option, a give-away hint left in
  an option such as "Tachycardia (by blocking M2 receptors)"). Fix small flaws and say what you changed
  in `note`. If a question cannot be made fair, leave it out and list it in your report.
- If a question depends on a picture, graph or table you cannot put into words, leave it out.

## What to produce
Write ONE JSON file (path given in your task) containing a JSON array. One object per question:

```json
{
  "source": "Renal CAT 2024 p.007 Q5",
  "type": "mcq",
  "text": "Which antiretroviral drug can also be used in the management of hepatitis B?",
  "options": ["Lamivudine", "Enfuvirtide", "Zidovudine", "Dolutegravir", "Abacavir"],
  "answer": "Lamivudine",
  "alt_answers": [],
  "marks": 1,
  "key_points": [],
  "explanation": "Lamivudine inhibits the reverse transcriptase of both HIV and hepatitis B virus, so it is used in both. Tenofovir and emtricitabine share this dual activity; the other options act only on HIV.",
  "topic_id": "pharm-antiretroviral-i",
  "confidence": "high",
  "note": ""
}
```

### The three types
1. `"mcq"`: multiple choice. EXACTLY 5 distinct options, and `answer` must be copied character for
   character from one of them. If the paper gives only 4 options, add one plausible wrong fifth option
   and say "added a fifth option" in `note`. If it gives more than 5, drop the weakest wrong ones.
   "All of the above / None of the above" options may stay if they are in the paper. Strip the a./b./A)
   labels from the options. `alt_answers: []`, `key_points: []`, `marks: 1`.
   - "Which is NOT / EXCEPT" questions are fine: keep the wording.
   - A block of True/False statements: make each statement its own question of type `"saq"` with text
     "True or false: <statement>", `answer` "True" or "False", `alt_answers` ["T"] or ["F"], marks 1.
     Only include statements you are certain about.
2. `"saq"`: a typed answer that is ONE thing: a drug, a class, an enzyme, a receptor, an organism, a
   number, one mechanism phrase of a few words. `answer` is that thing (1 to 4 words where possible);
   `alt_answers` lists every other wording a fair marker would accept (generic and other names,
   abbreviations, British/American spellings, singular/plural), up to 8. `options: []`,
   `key_points: []`, `marks: 1`. These questions are asked while an alarm rings, so the answer must be
   short and unambiguous. If more than one different fact would be a correct answer, it is not an
   `saq`: make it `long` (or reword the question so only one answer fits and note that you reworded).
3. `"long"`: anything that needs several items or an explanation ("List 4...", "Give 3...",
   "Classify...", "Explain the mechanism...", "Outline...", "Describe..."). Never asked in an alarm.
   - `marks`: the marks the paper gives that part; if none is stated, the number of items asked for;
     otherwise a sensible 2 to 5.
   - `answer`: the model answer as the student would write it, compact: items separated by "; " or
     short numbered lines. No waffle. It may list more acceptable items than are needed
     ("any 4 of: ...").
   - `key_points`: what earns the marks. A list of points; each point is a list of short wordings
     (1 to 4 words each, lower case) that would show the student has that point, e.g.
     `[["sedation","anxiolysis","reduce anxiety"],["amnesia"],["antisialagogue","reduce secretions","dry secretions"],["analgesia","pain relief"]]`.
     Give at least as many points as `marks` (more when any-N-of-many is acceptable). Each wording
     must be something a student would actually type; include common synonyms and drug names.
   - `options: []`, `alt_answers: []`.

### Splitting
- A question with parts a), b), c)... or i), ii), iii) becomes SEPARATE questions, one per part. Each
  must stand alone: fold any shared stem or scenario into each part's `text` ("A 45-year-old man on
  warfarin... Which test monitors his therapy?"). Do not write "a)" in the text.
- Put the marks in `marks`, not in the text: remove "(3 marks)" from `text`.
- A 20-mark essay with no parts: break it into 2 to 4 sensible `long` questions if it naturally has
  parts (classification, mechanism, adverse effects...); otherwise one `long` question, marks 5.

### Text
- Fix OCR errors, spelling and obvious typos; expand unclear abbreviations where it helps (MoA →
  mechanism of action, A/E → adverse effects, Rx → treatment); keep standard ones (ACE, NSAID, HIV).
  Keep the examiner's meaning. Use British spellings as the papers do (anaesthetic, oedema).
- If a question depends on a picture, graph or table that you cannot reproduce in words, skip it.
- If a question is unreadable even from the picture, skip it and mention the page in your report.

### `explanation` (every question)
Two to four sentences, about 40 to 80 words: why the answer is right, and for an mcq why the most
tempting wrong option is wrong. Teach, do not restate the question. No "The correct answer is...".

### `topic_id`
Pick the single best topic from the TOPIC LIST at the end of this document (format `topic_id | topic name`,
grouped under `## Section`). Use the most specific lecture topic that covers the question. If truly nothing fits, use the closest and say so in `note`.

### `confidence`
- `"high"`: you are sure the answer is correct and the question is clear and fair.
- `"low"`: any doubt at all: the science is contested or guideline-dependent, the question is
  ambiguous, the scan was hard to read, you reconstructed missing words, or two options could be
  defended. Say why in `note`. Low-confidence questions are held back for a human to check, so be
  honest: a wrong answer in a medical revision app is worse than a missing question.

### `source`
"<short name of the PDF> p.<page> Q<number>" so a human can find the question again.

### Duplicates
The same question often appears more than once. Within your range, keep one copy (the clearest).

### Also leave out
- Anything unreadable even from the page image (list the page in your report).
- Long-case essays with nothing a marker could check.

## Checking your own work before you hand it over

Each file must be a JSON array that passes this check. Run it if you can run code; otherwise go through
the rules by hand.

```python
import json, sys
TOPICS = set()  # fill from the TOPIC LIST below: every text before " | "
data = json.load(open(sys.argv[1]))
for i, q in enumerate(data):
    where = f"entry {i} ({q.get('source', '?')})"
    assert q["type"] in ("mcq", "saq", "long"), where
    assert q["text"].strip() and q["answer"].strip(), where
    assert q["topic_id"] in TOPICS, where + " unknown topic " + q["topic_id"]
    assert len(q["explanation"].split()) >= 25, where + " explanation too short"
    assert q["confidence"] in ("high", "low"), where
    if q["type"] == "mcq":
        o = q["options"]
        assert len(o) == 5 and len({x.strip().lower() for x in o}) == 5, where + " needs 5 different options"
        assert q["answer"] in o, where + " answer is not one of the options, letter for letter"
    if q["type"] == "saq":
        assert len(q["answer"]) <= 60 and not q["options"], where
    if q["type"] == "long":
        assert q["key_points"] and q["marks"] >= 1, where
    if q["confidence"] == "low":
        assert q.get("note"), where + " low confidence needs a note saying why"
print(len(data), "questions pass")
```

## What to hand back

1. **The JSON files**, named after the PDF and its pages, for example `renal_cat_2024_p001_040.json`.
   Plain JSON only: no comments, no trailing commas, straight double quotes.
2. **A short report per file**: pages covered; how many questions of each type; how many are low
   confidence; which questions you left out and why (duplicate, unfair, unreadable); and any question
   that fitted no topic well.
3. **Topics that seem to be missing.** If several questions belong to a lecture topic that is not in
   the list, do not invent an id: put them under the closest topic, say so in `note`, and name the
   missing topic in your report.

Repeats of questions already in the app are fine to include: the main session removes them on import
(there are about 2,300 Pharmacology questions in the bank already).

---

# TOPIC LIST (Pharmacology: 170 topics)

Format: `topic_id | topic name`, grouped under `## Section`. Use the `topic_id` exactly as written.
Topics marked "(no questions yet)" are empty in the app, so questions for them are especially welcome.
If a PDF is for a different unit (Pathology, Microbiology...), there is no topic list for it yet: stop
and say so, or, if asked to go on, group the questions under topic names you propose and leave
`topic_id` as an empty string.

## General principles
pharm-introduction-to-pharmacology-routes-of-drug-administration | Introduction to Pharmacology, Routes of drug administration
pharm-dosage-forms | Dosage forms
pharm-absorption | Absorption
pharm-transport-and-distribution | Transport and Distribution
pharm-bioavailability | Bioavailability
pharm-biotransformation | Biotransformation
pharm-excretion | Excretion
pharm-adverse-drug-reactions | Adverse drug reactions
pharm-receptors-and-signal-transduction-mechanisms | Receptors and signal transduction mechanisms
pharm-g-proteins-and-second-messengers | G-proteins and second messengers
pharm-drug-agonists-and-antagonists | Drug agonists and antagonists
pharm-log-dose-responses | Log/dose responses
pharm-introduction-to-pharmacokinetics | Introduction to Pharmacokinetics
pharm-time-course-of-drug-action | Time course of drug action
pharm-drug-level-monitoring-and-interpretation | Drug level monitoring and interpretation
pharm-effects-of-disease-on-drug-disposition | Effects of Disease on drug Disposition
pharm-drug-interactions | Drug Interactions
pharm-paediatric-clinical-pharmacology | Paediatric Clinical Pharmacology
pharm-geriatric-clinical-pharmacology | Geriatric Clinical Pharmacology
pharm-drugs-in-pregnancy-and-lactation | Drugs in pregnancy and lactation
pharm-genetic-medicine | Genetic Medicine

## Autonomic nervous system
pharm-introduction-to-autonomic-pharmacology | Introduction to autonomic pharmacology   (no questions yet)
pharm-organization-and-function-of-adrenergic-cholinergic-and-nanc-neu | Organization and function of Adrenergic, Cholinergic and NANC Neurotransmitter systems
pharm-direct-acting-cholinomimetics | Direct acting Cholinomimetics
pharm-indirect-acting-cholinomimetics | Indirect acting cholinomimetics
pharm-anticholinergics-and-ganglion-blockers | Anticholinergics and ganglion blockers
pharm-sympathomimetics | Sympathomimetics
pharm-sympatholytics | Sympatholytics
pharm-adrenoceptor-blockers | Adrenoceptor blockers

## Autacoids
pharm-introduction-to-autacoids-histamine-receptors-and-agonists | Introduction to Autacoids, Histamine, receptors and agonists
pharm-h1-receptor-antagonists | H1 receptor antagonists
pharm-eicosanoids | Eicosanoids
pharm-prostaglandins | Prostaglandins
pharm-serotonin-receptors-and-agonists | Serotonin receptors and agonists
pharm-serotonin-antagonists-and-ergot-alkaloids | Serotonin antagonists and ergot alkaloids
pharm-kinins | Kinins
pharm-the-polypeptides | The polypeptides
pharm-nitric-oxide | Nitric oxide

## Antibacterial drugs
pharm-introduction-to-anti-microbials-classification-and-resistance | Introduction to Anti-Microbials, Classification and resistance
pharm-sulfonamides-and-related-compounds | Sulfonamides and related compounds
pharm-introduction-to-beta-lactam-antibiotics-penicillins-pen-g-and-pe | Introduction to Beta lactam antibiotics, Penicillins, Pen G and Pen V and beta lactam inhibitors
pharm-other-penicillins-anti-staphylococcal-penicillins-amino-penicill | Other penicillins - anti-staphylococcal penicillins, Amino penicillins, carboxypenicillins, and ureidopenicillins
pharm-cephalosporins-and-cephamycins | Cephalosporins and Cephamycins
pharm-carbapenems-and-monobactams | Carbapenems and Monobactams
pharm-other-cell-wall-synthesis-inhibitors-streptogramins-oxazolidinon | Other cell wall synthesis inhibitors, streptogramins, oxazolidinones and polymyxins
pharm-aminoglycosides | Aminoglycosides
pharm-quinolones | Quinolones
pharm-macrolides | Macrolides

## Antimycobacterial drugs
pharm-anti-tb-drugs | Anti-TB drugs
pharm-anti-leprosy-drugs | Anti-Leprosy drugs

## Antifungal drugs
pharm-anti-fungals | Anti-fungals

## Antiviral and antiretroviral drugs
pharm-antivirals | Antivirals
pharm-anti-retrovirals | Anti-retrovirals
pharm-antiretroviral-i | Antiretroviral I
pharm-antiretroviral-ii | Antiretroviral II

## Antiprotozoal and antimalarial drugs
pharm-introduction-to-antiprotozoals-antimalarials-artemisinin-compoun | Introduction to Antiprotozoals, Antimalarials, Artemisinin Compounds
pharm-4-8-aminoquinolones-quinoline-methanols-phenanthrene-methanols-a | 4, 8 Aminoquinolones, Quinoline Methanols, Phenanthrene Methanols, Atovaquone
pharm-sulfonamides-antifolate-antimalarials | Sulfonamides, Antifolate Antimalarials
pharm-drugs-for-amebiasis-giardiasis-trichomoniasis-and-other-antiprot | Drugs for Amebiasis, Giardiasis, Trichomoniasis and Other Antiprotozoal
pharm-antibiotic-antimalarials-malarial-prophylaxis | Antibiotic Antimalarials, Malarial Prophylaxis

## Anthelmintics and ectoparasites
pharm-antihelminthics-i | Antihelminthics I
pharm-antihelminthics-ii-ectoparasites | Antihelminthics II, Ectoparasites

## Topical antimicrobials, disinfectants and antiseptics
pharm-topical-antimicrobials | Topical Antimicrobials
pharm-disinfectants-and-antiseptics | Disinfectants and Antiseptics

## NSAIDs and non-opioid analgesics
pharm-introduction-and-classification-of-analgesia-introduction-to-nsa | Introduction and Classification of Analgesia, Introduction to NSAIDS
pharm-salicylates-enolic-acids-nalbumetone-and-pyrazolone-derivatives | Salicylates, Enolic Acids, Nalbumetone and Pyrazolone Derivatives
pharm-paraminophenols-indole-acetic-acids-derivatives-heteroarylacetic | Paraminophenols, Indole Acetic Acids Derivatives, Heteroarylacetic Acids, Arylpropionic Acids, Selective COX 2 Inhibitors

## DMARDs and gout
pharm-introduction-to-dmards | Introduction to DMARDs
pharm-methotrexate-chloroquine-hydroxychloroquine | Methotrexate, Chloroquine, Hydroxychloroquine
pharm-azathioprine-sulfasalazine-leflunomide-and-other-conventional-dm | Azathioprine, Sulfasalazine, Leflunomide and Other Conventional DMARDs
pharm-biologic-dmards | Biologic DMARDS
pharm-drugs-used-in-the-management-of-gout | Drugs Used in the Management of Gout

## Immunopharmacology
pharm-the-immune-response-introduction-to-immunosuppressants | The Immune Response, Introduction to Immunosuppressants
pharm-calcineurin-inhibitors-antiproliferative-antimetabolite-drugs | Calcineurin Inhibitors, Antiproliferative, Antimetabolite Drugs
pharm-corticosteroids-immunosuppressant | Corticosteroids - Immunosuppressant
pharm-antibody-preparations | Antibody Preparations
pharm-immunomodulants-i | Immunomodulants I
pharm-immunomodulants-ii | Immunomodulants II   (no questions yet)

## Opioid analgesics
pharm-introduction-to-opioid-analgesics-classification-mechanism-of-ac | Introduction to Opioid Analgesics - Classification, Mechanism of Action, Morphine and Congeners
pharm-fentanyl-and-congeners-levorphanol-and-congeners-pethidine-and-c | Fentanyl and Congeners, Levorphanol and Congeners, Pethidine and Congeners
pharm-methadone-and-congeners-partial-agonists-opioid-antagonists | Methadone and Congeners, Partial Agonists, Opioid Antagonists
pharm-acute-opioid-toxicity | Acute Opioid Toxicity
pharm-opioid-use-and-abuse | Opioid Use and Abuse

## Anaesthetics and muscle relaxants
pharm-introduction-to-anesthesia-classification-and-mechanism-of-actio | Introduction to Anesthesia, Classification and Mechanism of Action of General Anesthetic Agents
pharm-inhalational-anesthetic-agents | Inhalational Anesthetic Agents
pharm-intravenous-anesthetic-agents | Intravenous Anesthetic Agents
pharm-local-anesthetic-agents | Local Anesthetic Agents
pharm-preanesthetic-agent | Preanesthetic Agent
pharm-neuromuscular-blocking-agents-spasmolytics | Neuromuscular Blocking Agents, Spasmolytics

## Intravenous fluids
pharm-intravenous-fluids | Intravenous Fluids

## Renal pharmacology and diuretics
pharm-introduction-to-renal-pharmacology-drugs-affecting-renal-water-c | Introduction to Renal Pharmacology, Drugs affecting Renal Water Conservation
pharm-introduction-to-diuretics-osmotic-diuretics | Introduction to Diuretics, Osmotic Diuretics
pharm-thiazide-diuretics-potassium-sparing-diuretics-carbonic-anhydras | Thiazide Diuretics, Potassium Sparing Diuretics, Carbonic Anhydrase Inhibitors, Loop Diuretics

## Cardiovascular drugs
pharm-lipid-lowering-agents | Lipid Lowering Agents
pharm-cardiac-glycosides-other-positive-ionotropic-drugs | Cardiac Glycosides, Other Positive Ionotropic Drugs
pharm-antiarrhythmic-drugs | Antiarrhythmic Drugs
pharm-introduction-to-antihypertensive-drugs-centrally-acting-sympatho | Introduction to Antihypertensive Drugs, Centrally Acting Sympatholytic Agents
pharm-adrenergic-neurone-blocking-drugs | Adrenergic Neurone Blocking Drugs
pharm-adrenoceptor-receptor-blocking-drugs-vasodilators | Adrenoceptor Receptor Blocking Drugs, Vasodilators
pharm-calcium-channel-blocker | Calcium Channel Blocker
pharm-inhibitors-of-angiotensin-raas-inhibitors | Inhibitors of Angiotensin (RAAS Inhibitors)
pharm-drugs-used-in-angina | Drugs Used In Angina

## Respiratory pharmacology
pharm-introduction-to-respiratory-pharmacology-drugs-used-in-asthma | Introduction to Respiratory Pharmacology, Drugs used in Asthma
pharm-sympathomimetics-methylxanthines | Sympathomimetics, Methylxanthines
pharm-antimuscarinic-agents | Antimuscarinic Agents
pharm-corticosteroids-in-asthma-mast-cell-stabilisers | Corticosteroids in Asthma, Mast Cell Stabilisers
pharm-leukotriene-inhibitors-other-drugs | Leukotriene Inhibitors, Other Drugs
pharm-cough-suppressants-and-expectorants | Cough Suppressants and Expectorants

## Central nervous system drugs
pharm-introduction-to-anticonvulsant-drugs-classification-of-seizures | Introduction to Anticonvulsant Drugs, Classification of Seizures, Classification of Anticonvulsant Drugs
pharm-antiseizure-barbiturates-hydantoin | Antiseizure Barbiturates, Hydantoin
pharm-iminostilbenes-succinimides-lamotrigine | Iminostilbenes, Succinimides, Lamotrigine
pharm-valproic-acid-oxazolidinediones-benzodiazepines | Valproic Acid, Oxazolidinediones, Benzodiazepines
pharm-gabapentin-vigabatrin-and-others | Gabapentin, Vigabatrin and Others
pharm-antidepressants-and-lithium | Antidepressants and Lithium
pharm-sedative-hypnotic-drugs | Sedative Hypnotic Drugs
pharm-major-tranquilizer | Major Tranquilizer
pharm-drug-addiction-and-abuse-addiction-to-cannabinoids-inhalants | Drug Addiction and Abuse, Addiction to Cannabinoids, Inhalants
pharm-addiction-to-opioids-cocaine-amphetamines | Addiction to Opioids, Cocaine, Amphetamines
pharm-addiction-to-cns-depressants-psychedelic-agents | Addiction to CNS Depressants, Psychedelic Agents
pharm-pharmacologic-management-of-parkinsonism-and-other-movement-diso | Pharmacologic management of Parkinsonism and Other Movement Disorders

## Gastrointestinal pharmacology
pharm-introduction-to-git-pharmacology-classification-of-drugs-for-pep | Introduction to GIT Pharmacology, Classification of Drugs for Peptic Ulcer Disease, Antacids
pharm-h2-receptor-antagonist-proton-pump-inhibitor | H2 Receptor Antagonist, Proton Pump Inhibitor
pharm-cytoprotective-agents-bismuth-compounds-sucralfate-etc | Cytoprotective Agents - Bismuth Compounds, Sucralfate etc
pharm-drugs-for-inflammatory-and-irritable-bowel-disease | Drugs for Inflammatory and Irritable Bowel disease
pharm-emetics-antiemetics-and-prokinetic-agents | Emetics, antiemetics and Prokinetic Agents
pharm-drugs-for-treating-pancreatic-disorders-aprotinin-glucagon-use-o | Drugs for treating Pancreatic Disorders, Aprotinin, Glucagon, Use of Pancreatic Extracts, Drugs for Portal Hypertension, Esophageal Varices and Hemorrhoids
pharm-digestants-and-drugs-used-to-dissolve-gallstones-bile-acids | Digestants and Drugs used to dissolve Gallstones; Bile Acids
pharm-antidiarrheal-agents-laxatives | Antidiarrheal Agents, Laxatives
pharm-appetite-stimulants-and-suppressants | Appetite Stimulants and Suppressants

## Endocrine pharmacology
pharm-introduction-to-endocrine-pharmacology-lh-fsh-chorionic-gonadotr | Introduction to Endocrine Pharmacology; LH, FSH, Chorionic Gonadotrophins, Androgens
pharm-adrenocortical-steroids-synthetic-analogues-inhibitor-of-synthes | Adrenocortical Steroids: Synthetic Analogues, Inhibitor of Synthesis and Action
pharm-gh-prolactin-and-its-inhibitor | GH, Prolactin and Its Inhibitor
pharm-thyroid-physiology-thyroid-hormonal-treatment-antithyroid-drugs | Thyroid Physiology, Thyroid Hormonal treatment, Antithyroid Drugs
pharm-aldosterone-oxytocin-vasopressin | Aldosterone, Oxytocin, Vasopressin
pharm-calcitonin-bisphosphonates-and-fluorides | Calcitonin, bisphosphonates and Fluorides
pharm-oestrogens-progestins-oral-contraceptives | Oestrogens, Progestins, Oral Contraceptives
pharm-calcium-vitamin-d-and-analogues | Calcium, Vitamin D and Analogues
pharm-insulins-and-other-parenteral-antidiabetic-drugs | Insulins and Other Parenteral Antidiabetic Drugs
pharm-oral-antidiabetic-drugs | Oral Antidiabetic Drugs

## Drugs acting on the blood
pharm-introduction-to-hematinics-iron-and-iron-salts-cobalamin-vit-b12 | Introduction to hematinics, Iron and Iron Salts, Cobalamin (Vit B12), folic acid
pharm-erythropoietin-myeloid-growth-factors-megakaryocyte-growth-facto | Erythropoietin, Myeloid Growth Factors, Megakaryocyte Growth Factors
pharm-antiplatelet-drugs | Antiplatelet Drugs
pharm-anticoagulant-drugs | Anticoagulant Drugs
pharm-thrombolytic-drugs-antifibrinolytic-drugs | Thrombolytic Drugs, Antifibrinolytic Drugs
pharm-vitamin-k-plasma-fractions-serine-protease-inhibitors-blood-prod | Vitamin K, Plasma fractions, Serine Protease Inhibitors, Blood products

## Vitamins
pharm-pyridoxine-pantothenic-acid-ascorbic-acid-biotin-inositol-carnit | Pyridoxine, Pantothenic acid, Ascorbic acid, Biotin, Inositol, Carnitine
pharm-thiamine-riboflavin-nicotinic-acid | Thiamine, Riboflavin, Nicotinic Acid

## Dermatological pharmacology
pharm-dermatological-preparations-introduction-glucocorticoids-retinoi | Dermatological Preparations - Introduction, Glucocorticoids, Retinoids
pharm-phototherapy-psoralens | Phototherapy, Psoralens   (no questions yet)
pharm-antipruritic-agents-keratolytic-agents | Antipruritic Agents, Keratolytic Agents
pharm-topical-cytotoxic-and-immunosuppressive-agents | Topical Cytotoxic and Immunosuppressive Agents
pharm-sunscreens-minoxidil-capsaicin | Sunscreens, Minoxidil, Capsaicin

## Anticancer drugs
pharm-anticancer-agents-general-principles-classification | Anticancer Agents - General Principles, Classification
pharm-alkylating-agents | Alkylating Agents
pharm-antimetabolites | Antimetabolites
pharm-vinca-alkaloids-platinum-agents | Vinca Alkaloids, Platinum Agents
pharm-epipodophyllotoxins-camptothecins-analogues | Epipodophyllotoxins, Camptothecins Analogues
pharm-tumor-antibiotics-anthracyclines | Tumor Antibiotics - Anthracyclines
pharm-hormonal-anticancer-drugs | Hormonal Anticancer Drugs
pharm-anticancer-small-molecule-inhibitors | Anticancer Small Molecule Inhibitors
pharm-anticancer-monoclonal-antibodies | Anticancer Monoclonal Antibodies
pharm-miscellaneous-anticancer-drugs | Miscellaneous Anticancer Drugs

## Toxicology and poisoning
pharm-emergency-management-of-poisoning | Emergency Management of Poisoning
pharm-opioids-and-barbiturate-poisoning | Opioids and Barbiturate Poisoning
pharm-acetaminophen-acetylsalicylic-acid-poisoning | Acetaminophen, Acetylsalicylic Acid Poisoning
pharm-paraffin-organophosphate-and-amphetamine-poisoning | Paraffin, Organophosphate and Amphetamine Poisoning
pharm-heavy-metal-poisoning | Heavy Metal Poisoning
pharm-carbon-monoxide-cyanide-acid-and-alkali-poisoning | Carbon Monoxide, Cyanide, Acid and Alkali Poisoning

## Drug development and regulation
pharm-drug-development-stages-regulations-governing-development-of-new | Drug Development Stages, Regulations governing development of new drugs
pharm-drug-registration-procedures-drug-procurement-market-categorizat | Drug Registration Procedures, Drug Procurement, Market Categorization of Drugs   (no questions yet)
