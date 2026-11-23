-- The Pharmacology outline: 28 sections and 170 topics, from the University of
-- Nairobi Clinical Pharmacology lecture list (MBChB II and III), in lecture
-- order. Topics are empty until questions are added, and new topics are for
-- paid plans until opened on the admin site. Safe to run again.

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-general-principles', 'pharmacology', 'section', 'General principles', 0)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-general-principles', sort_order = 0, name = 'General principles: mixed questions' where id = 'pharm-general-principles';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-pharmacology-routes-of-drug-administration', 'pharmacology', 'pharmacology-sec-general-principles', 'Introduction to Pharmacology, Routes of drug administration', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-dosage-forms', 'pharmacology', 'pharmacology-sec-general-principles', 'Dosage forms', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-absorption', 'pharmacology', 'pharmacology-sec-general-principles', 'Absorption', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-transport-and-distribution', 'pharmacology', 'pharmacology-sec-general-principles', 'Transport and Distribution', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-bioavailability', 'pharmacology', 'pharmacology-sec-general-principles', 'Bioavailability', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-biotransformation', 'pharmacology', 'pharmacology-sec-general-principles', 'Biotransformation', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-excretion', 'pharmacology', 'pharmacology-sec-general-principles', 'Excretion', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-adverse-drug-reactions', 'pharmacology', 'pharmacology-sec-general-principles', 'Adverse drug reactions', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-receptors-and-signal-transduction-mechanisms', 'pharmacology', 'pharmacology-sec-general-principles', 'Receptors and signal transduction mechanisms', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-g-proteins-and-second-messengers', 'pharmacology', 'pharmacology-sec-general-principles', 'G-proteins and second messengers', 10)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-agonists-and-antagonists', 'pharmacology', 'pharmacology-sec-general-principles', 'Drug agonists and antagonists', 11)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-log-dose-responses', 'pharmacology', 'pharmacology-sec-general-principles', 'Log/dose responses', 12)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-pharmacokinetics', 'pharmacology', 'pharmacology-sec-general-principles', 'Introduction to Pharmacokinetics', 13)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-time-course-of-drug-action', 'pharmacology', 'pharmacology-sec-general-principles', 'Time course of drug action', 14)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-level-monitoring-and-interpretation', 'pharmacology', 'pharmacology-sec-general-principles', 'Drug level monitoring and interpretation', 15)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-effects-of-disease-on-drug-disposition', 'pharmacology', 'pharmacology-sec-general-principles', 'Effects of Disease on drug Disposition', 16)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-interactions', 'pharmacology', 'pharmacology-sec-general-principles', 'Drug Interactions', 17)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-paediatric-clinical-pharmacology', 'pharmacology', 'pharmacology-sec-general-principles', 'Paediatric Clinical Pharmacology', 18)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-geriatric-clinical-pharmacology', 'pharmacology', 'pharmacology-sec-general-principles', 'Geriatric Clinical Pharmacology', 19)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-in-pregnancy-and-lactation', 'pharmacology', 'pharmacology-sec-general-principles', 'Drugs in pregnancy and lactation', 20)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-genetic-medicine', 'pharmacology', 'pharmacology-sec-general-principles', 'Genetic Medicine', 21)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-autonomic-nervous-system', 'pharmacology', 'section', 'Autonomic nervous system', 1)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-autonomic-nervous-system', sort_order = 0, name = 'Autonomic nervous system: mixed questions' where id = 'pharm-autonomic';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-autonomic-pharmacology', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Introduction to autonomic pharmacology', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-organization-and-function-of-adrenergic-cholinergic-and-nanc-neu', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Organization and function of Adrenergic, Cholinergic and NANC Neurotransmitter systems', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-direct-acting-cholinomimetics', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Direct acting Cholinomimetics', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-indirect-acting-cholinomimetics', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Indirect acting cholinomimetics', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anticholinergics-and-ganglion-blockers', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Anticholinergics and ganglion blockers', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sympathomimetics', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Sympathomimetics', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sympatholytics', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Sympatholytics', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-adrenoceptor-blockers', 'pharmacology', 'pharmacology-sec-autonomic-nervous-system', 'Adrenoceptor blockers', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-autacoids', 'pharmacology', 'section', 'Autacoids', 2)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-autacoids-histamine-receptors-and-agonists', 'pharmacology', 'pharmacology-sec-autacoids', 'Introduction to Autacoids, Histamine, receptors and agonists', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-h1-receptor-antagonists', 'pharmacology', 'pharmacology-sec-autacoids', 'H1 receptor antagonists', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-eicosanoids', 'pharmacology', 'pharmacology-sec-autacoids', 'Eicosanoids', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-prostaglandins', 'pharmacology', 'pharmacology-sec-autacoids', 'Prostaglandins', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-serotonin-receptors-and-agonists', 'pharmacology', 'pharmacology-sec-autacoids', 'Serotonin receptors and agonists', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-serotonin-antagonists-and-ergot-alkaloids', 'pharmacology', 'pharmacology-sec-autacoids', 'Serotonin antagonists and ergot alkaloids', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-kinins', 'pharmacology', 'pharmacology-sec-autacoids', 'Kinins', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-the-polypeptides', 'pharmacology', 'pharmacology-sec-autacoids', 'The polypeptides', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-nitric-oxide', 'pharmacology', 'pharmacology-sec-autacoids', 'Nitric oxide', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-antimicrobials', 'pharmacology', 'section', 'Antibacterial drugs', 3)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-antimicrobials', sort_order = 0, name = 'Antibacterial drugs: mixed questions' where id = 'pharm-antimicrobials';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-anti-microbials-classification-and-resistance', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Introduction to Anti-Microbials, Classification and resistance', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sulfonamides-and-related-compounds', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Sulfonamides and related compounds', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-beta-lactam-antibiotics-penicillins-pen-g-and-pe', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Introduction to Beta lactam antibiotics, Penicillins, Pen G and Pen V and beta lactam inhibitors', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-other-penicillins-anti-staphylococcal-penicillins-amino-penicill', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Other penicillins - anti-staphylococcal penicillins, Amino penicillins, carboxypenicillins, and ureidopenicillins', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-cephalosporins-and-cephamycins', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Cephalosporins and Cephamycins', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-carbapenems-and-monobactams', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Carbapenems and Monobactams', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-other-cell-wall-synthesis-inhibitors-streptogramins-oxazolidinon', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Other cell wall synthesis inhibitors, streptogramins, oxazolidinones and polymyxins', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-aminoglycosides', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Aminoglycosides', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-quinolones', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Quinolones', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-macrolides', 'pharmacology', 'pharmacology-sec-antimicrobials', 'Macrolides', 10)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-antimycobacterial-drugs', 'pharmacology', 'section', 'Antimycobacterial drugs', 4)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anti-tb-drugs', 'pharmacology', 'pharmacology-sec-antimycobacterial-drugs', 'Anti-TB drugs', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anti-leprosy-drugs', 'pharmacology', 'pharmacology-sec-antimycobacterial-drugs', 'Anti-Leprosy drugs', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-antifungal-drugs', 'pharmacology', 'section', 'Antifungal drugs', 5)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anti-fungals', 'pharmacology', 'pharmacology-sec-antifungal-drugs', 'Anti-fungals', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-antiviral-and-antiretroviral-drugs', 'pharmacology', 'section', 'Antiviral and antiretroviral drugs', 6)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antivirals', 'pharmacology', 'pharmacology-sec-antiviral-and-antiretroviral-drugs', 'Antivirals', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anti-retrovirals', 'pharmacology', 'pharmacology-sec-antiviral-and-antiretroviral-drugs', 'Anti-retrovirals', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antiretroviral-i', 'pharmacology', 'pharmacology-sec-antiviral-and-antiretroviral-drugs', 'Antiretroviral I', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antiretroviral-ii', 'pharmacology', 'pharmacology-sec-antiviral-and-antiretroviral-drugs', 'Antiretroviral II', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-antiprotozoal-and-antimalarial-drugs', 'pharmacology', 'section', 'Antiprotozoal and antimalarial drugs', 7)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-antiprotozoals-antimalarials-artemisinin-compoun', 'pharmacology', 'pharmacology-sec-antiprotozoal-and-antimalarial-drugs', 'Introduction to Antiprotozoals, Antimalarials, Artemisinin Compounds', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-4-8-aminoquinolones-quinoline-methanols-phenanthrene-methanols-a', 'pharmacology', 'pharmacology-sec-antiprotozoal-and-antimalarial-drugs', '4, 8 Aminoquinolones, Quinoline Methanols, Phenanthrene Methanols, Atovaquone', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sulfonamides-antifolate-antimalarials', 'pharmacology', 'pharmacology-sec-antiprotozoal-and-antimalarial-drugs', 'Sulfonamides, Antifolate Antimalarials', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-for-amebiasis-giardiasis-trichomoniasis-and-other-antiprot', 'pharmacology', 'pharmacology-sec-antiprotozoal-and-antimalarial-drugs', 'Drugs for Amebiasis, Giardiasis, Trichomoniasis and Other Antiprotozoal', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antibiotic-antimalarials-malarial-prophylaxis', 'pharmacology', 'pharmacology-sec-antiprotozoal-and-antimalarial-drugs', 'Antibiotic Antimalarials, Malarial Prophylaxis', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-anthelmintics-and-ectoparasites', 'pharmacology', 'section', 'Anthelmintics and ectoparasites', 8)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antihelminthics-i', 'pharmacology', 'pharmacology-sec-anthelmintics-and-ectoparasites', 'Antihelminthics I', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antihelminthics-ii-ectoparasites', 'pharmacology', 'pharmacology-sec-anthelmintics-and-ectoparasites', 'Antihelminthics II, Ectoparasites', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-topical-antimicrobials-disinfectants-and-antiseptics', 'pharmacology', 'section', 'Topical antimicrobials, disinfectants and antiseptics', 9)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-topical-antimicrobials', 'pharmacology', 'pharmacology-sec-topical-antimicrobials-disinfectants-and-antiseptics', 'Topical Antimicrobials', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-disinfectants-and-antiseptics', 'pharmacology', 'pharmacology-sec-topical-antimicrobials-disinfectants-and-antiseptics', 'Disinfectants and Antiseptics', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-analgesics-and-anti-inflammatory-drugs', 'pharmacology', 'section', 'NSAIDs and non-opioid analgesics', 10)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-analgesics-and-anti-inflammatory-drugs', sort_order = 0, name = 'NSAIDs and non-opioid analgesics: mixed questions' where id = 'pharm-analgesics';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-and-classification-of-analgesia-introduction-to-nsa', 'pharmacology', 'pharmacology-sec-analgesics-and-anti-inflammatory-drugs', 'Introduction and Classification of Analgesia, Introduction to NSAIDS', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-salicylates-enolic-acids-nalbumetone-and-pyrazolone-derivatives', 'pharmacology', 'pharmacology-sec-analgesics-and-anti-inflammatory-drugs', 'Salicylates, Enolic Acids, Nalbumetone and Pyrazolone Derivatives', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-paraminophenols-indole-acetic-acids-derivatives-heteroarylacetic', 'pharmacology', 'pharmacology-sec-analgesics-and-anti-inflammatory-drugs', 'Paraminophenols, Indole Acetic Acids Derivatives, Heteroarylacetic Acids, Arylpropionic Acids, Selective COX 2 Inhibitors', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-dmards-and-gout', 'pharmacology', 'section', 'DMARDs and gout', 11)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-dmards', 'pharmacology', 'pharmacology-sec-dmards-and-gout', 'Introduction to DMARDs', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-methotrexate-chloroquine-hydroxychloroquine', 'pharmacology', 'pharmacology-sec-dmards-and-gout', 'Methotrexate, Chloroquine, Hydroxychloroquine', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-azathioprine-sulfasalazine-leflunomide-and-other-conventional-dm', 'pharmacology', 'pharmacology-sec-dmards-and-gout', 'Azathioprine, Sulfasalazine, Leflunomide and Other Conventional DMARDs', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-biologic-dmards', 'pharmacology', 'pharmacology-sec-dmards-and-gout', 'Biologic DMARDS', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-used-in-the-management-of-gout', 'pharmacology', 'pharmacology-sec-dmards-and-gout', 'Drugs Used in the Management of Gout', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-immunopharmacology', 'pharmacology', 'section', 'Immunopharmacology', 12)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-the-immune-response-introduction-to-immunosuppressants', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'The Immune Response, Introduction to Immunosuppressants', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-calcineurin-inhibitors-antiproliferative-antimetabolite-drugs', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'Calcineurin Inhibitors, Antiproliferative, Antimetabolite Drugs', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-corticosteroids-immunosuppressant', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'Corticosteroids - Immunosuppressant', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antibody-preparations', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'Antibody Preparations', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-immunomodulants-i', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'Immunomodulants I', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-immunomodulants-ii', 'pharmacology', 'pharmacology-sec-immunopharmacology', 'Immunomodulants II', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-opioid-analgesics', 'pharmacology', 'section', 'Opioid analgesics', 13)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-opioid-analgesics-classification-mechanism-of-ac', 'pharmacology', 'pharmacology-sec-opioid-analgesics', 'Introduction to Opioid Analgesics - Classification, Mechanism of Action, Morphine and Congeners', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-fentanyl-and-congeners-levorphanol-and-congeners-pethidine-and-c', 'pharmacology', 'pharmacology-sec-opioid-analgesics', 'Fentanyl and Congeners, Levorphanol and Congeners, Pethidine and Congeners', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-methadone-and-congeners-partial-agonists-opioid-antagonists', 'pharmacology', 'pharmacology-sec-opioid-analgesics', 'Methadone and Congeners, Partial Agonists, Opioid Antagonists', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-acute-opioid-toxicity', 'pharmacology', 'pharmacology-sec-opioid-analgesics', 'Acute Opioid Toxicity', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-opioid-use-and-abuse', 'pharmacology', 'pharmacology-sec-opioid-analgesics', 'Opioid Use and Abuse', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-anaesthetics-and-muscle-relaxants', 'pharmacology', 'section', 'Anaesthetics and muscle relaxants', 14)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-anesthesia-classification-and-mechanism-of-actio', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Introduction to Anesthesia, Classification and Mechanism of Action of General Anesthetic Agents', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-inhalational-anesthetic-agents', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Inhalational Anesthetic Agents', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-intravenous-anesthetic-agents', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Intravenous Anesthetic Agents', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-local-anesthetic-agents', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Local Anesthetic Agents', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-preanesthetic-agent', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Preanesthetic Agent', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-neuromuscular-blocking-agents-spasmolytics', 'pharmacology', 'pharmacology-sec-anaesthetics-and-muscle-relaxants', 'Neuromuscular Blocking Agents, Spasmolytics', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-intravenous-fluids', 'pharmacology', 'section', 'Intravenous fluids', 15)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-intravenous-fluids', 'pharmacology', 'pharmacology-sec-intravenous-fluids', 'Intravenous Fluids', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-renal-pharmacology-and-diuretics', 'pharmacology', 'section', 'Renal pharmacology and diuretics', 16)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-renal-pharmacology-drugs-affecting-renal-water-c', 'pharmacology', 'pharmacology-sec-renal-pharmacology-and-diuretics', 'Introduction to Renal Pharmacology, Drugs affecting Renal Water Conservation', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-diuretics-osmotic-diuretics', 'pharmacology', 'pharmacology-sec-renal-pharmacology-and-diuretics', 'Introduction to Diuretics, Osmotic Diuretics', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-thiazide-diuretics-potassium-sparing-diuretics-carbonic-anhydras', 'pharmacology', 'pharmacology-sec-renal-pharmacology-and-diuretics', 'Thiazide Diuretics, Potassium Sparing Diuretics, Carbonic Anhydrase Inhibitors, Loop Diuretics', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-cardiovascular-drugs', 'pharmacology', 'section', 'Cardiovascular drugs', 17)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-cardiovascular-drugs', sort_order = 0, name = 'Cardiovascular drugs: mixed questions' where id = 'pharm-cardiovascular';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-lipid-lowering-agents', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Lipid Lowering Agents', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-cardiac-glycosides-other-positive-ionotropic-drugs', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Cardiac Glycosides, Other Positive Ionotropic Drugs', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antiarrhythmic-drugs', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Antiarrhythmic Drugs', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-antihypertensive-drugs-centrally-acting-sympatho', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Introduction to Antihypertensive Drugs, Centrally Acting Sympatholytic Agents', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-adrenergic-neurone-blocking-drugs', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Adrenergic Neurone Blocking Drugs', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-adrenoceptor-receptor-blocking-drugs-vasodilators', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Adrenoceptor Receptor Blocking Drugs, Vasodilators', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-calcium-channel-blocker', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Calcium Channel Blocker', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-inhibitors-of-angiotensin-raas-inhibitors', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Inhibitors of Angiotensin (RAAS Inhibitors)', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-used-in-angina', 'pharmacology', 'pharmacology-sec-cardiovascular-drugs', 'Drugs Used In Angina', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-respiratory-pharmacology', 'pharmacology', 'section', 'Respiratory pharmacology', 18)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-respiratory-pharmacology-drugs-used-in-asthma', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Introduction to Respiratory Pharmacology, Drugs used in Asthma', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sympathomimetics-methylxanthines', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Sympathomimetics, Methylxanthines', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antimuscarinic-agents', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Antimuscarinic Agents', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-corticosteroids-in-asthma-mast-cell-stabilisers', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Corticosteroids in Asthma, Mast Cell Stabilisers', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-leukotriene-inhibitors-other-drugs', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Leukotriene Inhibitors, Other Drugs', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-cough-suppressants-and-expectorants', 'pharmacology', 'pharmacology-sec-respiratory-pharmacology', 'Cough Suppressants and Expectorants', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-central-nervous-system-drugs', 'pharmacology', 'section', 'Central nervous system drugs', 19)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
update public.topics set section_id = 'pharmacology-sec-central-nervous-system-drugs', sort_order = 0, name = 'Central nervous system drugs: mixed questions' where id = 'pharm-cns';
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-anticonvulsant-drugs-classification-of-seizures', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Introduction to Anticonvulsant Drugs, Classification of Seizures, Classification of Anticonvulsant Drugs', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antiseizure-barbiturates-hydantoin', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Antiseizure Barbiturates, Hydantoin', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-iminostilbenes-succinimides-lamotrigine', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Iminostilbenes, Succinimides, Lamotrigine', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-valproic-acid-oxazolidinediones-benzodiazepines', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Valproic Acid, Oxazolidinediones, Benzodiazepines', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-gabapentin-vigabatrin-and-others', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Gabapentin, Vigabatrin and Others', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antidepressants-and-lithium', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Antidepressants and Lithium', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sedative-hypnotic-drugs', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Sedative Hypnotic Drugs', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-major-tranquilizer', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Major Tranquilizer', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-addiction-and-abuse-addiction-to-cannabinoids-inhalants', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Drug Addiction and Abuse, Addiction to Cannabinoids, Inhalants', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-addiction-to-opioids-cocaine-amphetamines', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Addiction to Opioids, Cocaine, Amphetamines', 10)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-addiction-to-cns-depressants-psychedelic-agents', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Addiction to CNS Depressants, Psychedelic Agents', 11)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-pharmacologic-management-of-parkinsonism-and-other-movement-diso', 'pharmacology', 'pharmacology-sec-central-nervous-system-drugs', 'Pharmacologic management of Parkinsonism and Other Movement Disorders', 12)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-gastrointestinal-pharmacology', 'pharmacology', 'section', 'Gastrointestinal pharmacology', 20)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-git-pharmacology-classification-of-drugs-for-pep', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Introduction to GIT Pharmacology, Classification of Drugs for Peptic Ulcer Disease, Antacids', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-h2-receptor-antagonist-proton-pump-inhibitor', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'H2 Receptor Antagonist, Proton Pump Inhibitor', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-cytoprotective-agents-bismuth-compounds-sucralfate-etc', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Cytoprotective Agents - Bismuth Compounds, Sucralfate etc', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-for-inflammatory-and-irritable-bowel-disease', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Drugs for Inflammatory and Irritable Bowel disease', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-emetics-antiemetics-and-prokinetic-agents', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Emetics, antiemetics and Prokinetic Agents', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drugs-for-treating-pancreatic-disorders-aprotinin-glucagon-use-o', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Drugs for treating Pancreatic Disorders, Aprotinin, Glucagon, Use of Pancreatic Extracts, Drugs for Portal Hypertension, Esophageal Varices and Hemorrhoids', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-digestants-and-drugs-used-to-dissolve-gallstones-bile-acids', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Digestants and Drugs used to dissolve Gallstones; Bile Acids', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antidiarrheal-agents-laxatives', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Antidiarrheal Agents, Laxatives', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-appetite-stimulants-and-suppressants', 'pharmacology', 'pharmacology-sec-gastrointestinal-pharmacology', 'Appetite Stimulants and Suppressants', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-endocrine-pharmacology', 'pharmacology', 'section', 'Endocrine pharmacology', 21)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-endocrine-pharmacology-lh-fsh-chorionic-gonadotr', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Introduction to Endocrine Pharmacology; LH, FSH, Chorionic Gonadotrophins, Androgens', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-adrenocortical-steroids-synthetic-analogues-inhibitor-of-synthes', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Adrenocortical Steroids: Synthetic Analogues, Inhibitor of Synthesis and Action', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-gh-prolactin-and-its-inhibitor', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'GH, Prolactin and Its Inhibitor', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-thyroid-physiology-thyroid-hormonal-treatment-antithyroid-drugs', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Thyroid Physiology, Thyroid Hormonal treatment, Antithyroid Drugs', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-aldosterone-oxytocin-vasopressin', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Aldosterone, Oxytocin, Vasopressin', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-calcitonin-bisphosphonates-and-fluorides', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Calcitonin, bisphosphonates and Fluorides', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-oestrogens-progestins-oral-contraceptives', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Oestrogens, Progestins, Oral Contraceptives', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-calcium-vitamin-d-and-analogues', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Calcium, Vitamin D and Analogues', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-insulins-and-other-parenteral-antidiabetic-drugs', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Insulins and Other Parenteral Antidiabetic Drugs', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-oral-antidiabetic-drugs', 'pharmacology', 'pharmacology-sec-endocrine-pharmacology', 'Oral Antidiabetic Drugs', 10)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-drugs-acting-on-the-blood', 'pharmacology', 'section', 'Drugs acting on the blood', 22)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-introduction-to-hematinics-iron-and-iron-salts-cobalamin-vit-b12', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Introduction to hematinics, Iron and Iron Salts, Cobalamin (Vit B12), folic acid', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-erythropoietin-myeloid-growth-factors-megakaryocyte-growth-facto', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Erythropoietin, Myeloid Growth Factors, Megakaryocyte Growth Factors', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antiplatelet-drugs', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Antiplatelet Drugs', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anticoagulant-drugs', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Anticoagulant Drugs', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-thrombolytic-drugs-antifibrinolytic-drugs', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Thrombolytic Drugs, Antifibrinolytic Drugs', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-vitamin-k-plasma-fractions-serine-protease-inhibitors-blood-prod', 'pharmacology', 'pharmacology-sec-drugs-acting-on-the-blood', 'Vitamin K, Plasma fractions, Serine Protease Inhibitors, Blood products', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-vitamins', 'pharmacology', 'section', 'Vitamins', 23)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-pyridoxine-pantothenic-acid-ascorbic-acid-biotin-inositol-carnit', 'pharmacology', 'pharmacology-sec-vitamins', 'Pyridoxine, Pantothenic acid, Ascorbic acid, Biotin, Inositol, Carnitine', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-thiamine-riboflavin-nicotinic-acid', 'pharmacology', 'pharmacology-sec-vitamins', 'Thiamine, Riboflavin, Nicotinic Acid', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-dermatological-pharmacology', 'pharmacology', 'section', 'Dermatological pharmacology', 24)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-dermatological-preparations-introduction-glucocorticoids-retinoi', 'pharmacology', 'pharmacology-sec-dermatological-pharmacology', 'Dermatological Preparations - Introduction, Glucocorticoids, Retinoids', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-phototherapy-psoralens', 'pharmacology', 'pharmacology-sec-dermatological-pharmacology', 'Phototherapy, Psoralens', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antipruritic-agents-keratolytic-agents', 'pharmacology', 'pharmacology-sec-dermatological-pharmacology', 'Antipruritic Agents, Keratolytic Agents', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-topical-cytotoxic-and-immunosuppressive-agents', 'pharmacology', 'pharmacology-sec-dermatological-pharmacology', 'Topical Cytotoxic and Immunosuppressive Agents', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-sunscreens-minoxidil-capsaicin', 'pharmacology', 'pharmacology-sec-dermatological-pharmacology', 'Sunscreens, Minoxidil, Capsaicin', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-anticancer-drugs', 'pharmacology', 'section', 'Anticancer drugs', 25)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anticancer-agents-general-principles-classification', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Anticancer Agents - General Principles, Classification', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-alkylating-agents', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Alkylating Agents', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-antimetabolites', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Antimetabolites', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-vinca-alkaloids-platinum-agents', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Vinca Alkaloids, Platinum Agents', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-epipodophyllotoxins-camptothecins-analogues', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Epipodophyllotoxins, Camptothecins Analogues', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-tumor-antibiotics-anthracyclines', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Tumor Antibiotics - Anthracyclines', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-hormonal-anticancer-drugs', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Hormonal Anticancer Drugs', 7)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anticancer-small-molecule-inhibitors', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Anticancer Small Molecule Inhibitors', 8)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-anticancer-monoclonal-antibodies', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Anticancer Monoclonal Antibodies', 9)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-miscellaneous-anticancer-drugs', 'pharmacology', 'pharmacology-sec-anticancer-drugs', 'Miscellaneous Anticancer Drugs', 10)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-toxicology-and-poisoning', 'pharmacology', 'section', 'Toxicology and poisoning', 26)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-emergency-management-of-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Emergency Management of Poisoning', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-opioids-and-barbiturate-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Opioids and Barbiturate Poisoning', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-acetaminophen-acetylsalicylic-acid-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Acetaminophen, Acetylsalicylic Acid Poisoning', 3)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-paraffin-organophosphate-and-amphetamine-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Paraffin, Organophosphate and Amphetamine Poisoning', 4)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-heavy-metal-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Heavy Metal Poisoning', 5)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-carbon-monoxide-cyanide-acid-and-alkali-poisoning', 'pharmacology', 'pharmacology-sec-toxicology-and-poisoning', 'Carbon Monoxide, Cyanide, Acid and Alkali Poisoning', 6)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;

insert into public.sections (id, unit_id, kind, name, sort_order) values ('pharmacology-sec-drug-development-and-regulation', 'pharmacology', 'section', 'Drug development and regulation', 27)
  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order, deleted_at = null;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-development-stages-regulations-governing-development-of-new', 'pharmacology', 'pharmacology-sec-drug-development-and-regulation', 'Drug Development Stages, Regulations governing development of new drugs', 1)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
insert into public.topics (id, unit_id, section_id, name, sort_order) values ('pharm-drug-registration-procedures-drug-procurement-market-categorizat', 'pharmacology', 'pharmacology-sec-drug-development-and-regulation', 'Drug Registration Procedures, Drug Procurement, Market Categorization of Drugs', 2)
  on conflict (id) do update set section_id = excluded.section_id, name = excluded.name, sort_order = excluded.sort_order;
