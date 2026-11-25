# Datasets for the review-summarisation model

**Checked 25 November 2026.** Every entry below was verified against the live host — the links
resolve and the row counts are real.

---

## 0. First, the distinction that decides everything

There are two kinds of dataset, and picking the wrong kind is the most common way this project
stalls:

| Kind | What it gives you | What you can train |
|---|---|---|
| **Paired** — `(reviews, summary)` | Input *and* the target summary | Supervised summarisation — this is what you need |
| **Unpaired** — reviews only | Text, no target | Pretraining, domain adaptation, clustering — **not** a summariser on its own |

Most "review datasets" (Amazon, Yelp) are **unpaired**. They contain millions of reviews and no
summaries. Training a summariser on them alone is impossible; you need pairs.

Also note the **shape** of your own task. QuickFix summarises *several reviews of one worker*
into one paragraph — that is **multi-document** opinion summarisation, not single-document.
Datasets differ on this, and it matters.

---

## 1. Paired datasets — the ones you can actually train on

### 1.1 Opinosis — the canonical choice, and the right *shape*

| | |
|---|---|
| Where | UCI: https://archive.ics.uci.edu/dataset/175/opinosis · Hugging Face: `kavgan/opinosis` |
| Size | 51 topics; ~1 000 review sentences; ~5 reference summaries per topic |
| Format | one `.txt.data` file per topic + human-written summaries |
| Language | English |
| Licence | Apache-2.0 (HF mirror); UCI citation required |
| Source | Tripadvisor, Edmunds, Amazon (Ganesan et al., 2010) |

**Why it matters:** each topic is a *cluster of reviews about one thing* (battery life of a
netbook, a hotel's staff), and the gold summary is written from **all of them**. That is exactly
your task shape — several reviews → one summary.

**Limitations to state in the report:** it is tiny, and the summaries are extractive in style
(they reuse phrases from the reviews). It is an **evaluation** set and a fine-tuning set, not
enough to train a model from scratch.

```python
from datasets import load_dataset
ds = load_dataset("kavgan/opinosis")   # script-based; needs trust_remote_code=True on newer versions
```

### 1.2 Amazon review → summary, 71 493 rows

| | |
|---|---|
| Where | https://huggingface.co/datasets/YuyangHuang/amazonReviewSummary |
| Size | **71 493 rows** (single `train` split — you split it yourself) |
| Columns | `review`, `summary`, `prompt`, `instructions` |
| Language | English |
| Licence | **none declared** — see §5 |
| Shape | **single review → summary** (instruction style) |

This is the volume dataset. 71k pairs is enough to fine-tune a small seq2seq model into
something that produces fluent review summaries.

```python
from datasets import load_dataset
ds = load_dataset("YuyangHuang/amazonReviewSummary", split="train")
print(ds[0]["review"][:300]); print(ds[0]["summary"][:300])
```

Two caveats: the summaries are **bullet-point style** ("Advantages: 1. Effectiveness…"), and
the licence is undeclared, so treat it as research use and say so in the report.

### 1.3 Restaurant reviews with aspect sentiments, 996 rows

| | |
|---|---|
| Where | https://huggingface.co/datasets/navdeep-singh/sentiment-aware-review-summarization |
| Size | 896 train / 100 test (~1 MB) |
| Columns | `review`, `summary`, plus per-aspect sentiment: Ambiance, Cleanliness, Food, Service, Value |
| Language | English |
| Licence | none declared |
| Shape | single review → summary, **aspect-aware** |

Small, but the only one here with **structured aspect labels**. Useful if you want the summary to
be organised by aspect ("cleanliness: good, service: slow") — which reads well on a worker
profile.

### 1.4 Synthesised Amazon/Yelp summarisation data (259 rows)

`schneiderkamplab/sapient-synth-flan-niv2-fsopt-data-task672-amazon-yelp-summarization`

Machine-generated in FLAN style. **Not recommended as training data** — 259 synthetic rows teach
a model the generator's quirks, not summarisation. Mention it only if asked whether you
considered augmentation.

---

## 2. Unpaired datasets — for pretraining and domain adaptation

Use these only if you want to pretrain an encoder on review language first, or to build a
domain-specific vocabulary. They cannot teach summarisation by themselves.

| Dataset | Where | Size | Use |
|---|---|---|---|
| **Amazon Reviews 2023** | https://huggingface.co/datasets/McAuley-Lab/Amazon-Reviews-2023 | 571 M reviews, 1996–2023 | Domain pretraining, embeddings |
| **Yelp Review Full** | https://huggingface.co/datasets/Yelp/yelp_review_full | 700 k reviews + 1–5 stars | Domain pretraining; star rating gives a weak sentiment signal |
| **Amazon Fine Food Reviews** | Kaggle: `snap/amazon-fine-food-reviews` | 568 k reviews | Same |

---

## 3. Generic summarisation corpora — only for warm-starting

If you want the model to learn "summarise" as a task before specialising on reviews:

| Dataset | Where | Size | Note |
|---|---|---|---|
| CNN / DailyMail | `abisee/cnn_dailymail` | 312 k article→summary pairs | News, not reviews; classic baseline |
| XSum | `EdinburghNLP/xsum` | 227 k BBC pairs | Extreme summarisation, one sentence |

These teach fluent compression but the domain is wrong. Use them only as a first stage, then
fine-tune on §1.

---

## 4. What I would actually do

Given: English only, no API calls at inference, one laptop or Colab, and a report to defend.

### Stage 1 — fine-tune a small seq2seq (recommended)

```
FLAN-T5-small (80M params)  or  T5-small (60M)
        ↓ fine-tune on 60k of the Amazon pairs (§1.2)     ~2–4 h on a free Colab T4
        ↓ fine-tune on Opinosis (§1.1), multi-document     ~10 min
        ↓ evaluate ROUGE on the held-out 11k Amazon pairs + Opinosis
```

Why this order: the 71k pairs give volume and fluency; Opinosis re-shapes the model for
*multiple reviews → one summary*, which is your actual inference-time input.

Export for serving: keep it in the **proxy** (Python, one endpoint) rather than shipping a
TFLite model — the phone already calls `SUMMARY_PROXY_URL`, so nothing in the app changes.

### Stage 2 — if pretrained weights are not allowed

Then you need millions of pairs and a GPU budget you probably do not have. A from-scratch
transformer trained on 71k pairs will produce poor summaries. **Clarify this with your
supervisor before starting:** "no APIs" usually means *no external API calls*, and running a
publicly available model locally is normally allowed. That distinction decides whether this is a
weekend or a semester.

### Stage 3 — the fallback that is already built

If training does not finish in time, your existing TF-IDF extractive summariser in
`services/summary_service.dart` needs no training and works offline. Keep it as the shipped
default and present the trained model as the improvement — that is a legitimate, honest story:
*"classical baseline shipped, neural model trained and evaluated."*

---

## 5. Licensing — put this in the report

| Dataset | Licence | What to write |
|---|---|---|
| Opinosis | Apache-2.0 / cite Ganesan et al. 2010 | Safe to use and redistribute the code; cite the paper |
| Amazon pairs (HF) | **undeclared** | "Used for research; no licence declared by the uploader" |
| Restaurant aspect set | **undeclared** | Same |
| Amazon Reviews 2023 | research use, cite McAuley Lab | Cite the dataset paper |
| Yelp | Yelp Dataset Agreement | Do not redistribute the raw data |

An undeclared licence is not a blocker for a university project, but **say it** rather than
letting an examiner find it.

---

## 6. How to evaluate — and what number to quote

- **ROUGE-1 / ROUGE-2 / ROUGE-L** on a held-out split. Report all three; ROUGE-L is the one to
  quote in the abstract.
- **Opinosis** is multi-reference, so it gives a fairer score than a single-reference set.
- **Also report a human check**: 20 summaries rated for factual consistency. Neural summarisers
  hallucinate, and a ROUGE score will not reveal it. Saying "we measured hallucination on 20
  samples and found N" is the kind of thing that earns marks.

---

## 7. Commands to start

```bash
pip install datasets transformers sentencepiece evaluate rouge_score
```

```python
from datasets import load_dataset
amazon = load_dataset("YuyangHuang/amazonReviewSummary", split="train").train_test_split(test_size=0.15, seed=42)
print(len(amazon["train"]), len(amazon["test"]))     # ~60.7k / ~10.7k
```

```python
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
tok = AutoTokenizer.from_pretrained("google/flan-t5-small")
model = AutoModelForSeq2SeqLM.from_pretrained("google/flan-t5-small")
```

Then the usual `Seq2SeqTrainer` loop with `input_ids` from `review` and `labels` from `summary`,
truncating reviews to 512 tokens and summaries to 128.

---

## 8. One-paragraph summary for the report

*"We fine-tuned a small sequence-to-sequence model on 71 493 English Amazon review–summary pairs,
then adapted it to multi-document input using the Opinosis corpus of 51 review topics with
human-written reference summaries. Evaluation used ROUGE-1/2/L on a held-out split plus a
20-sample human check for factual consistency. The shipped app retains an on-device TF-IDF
extractive summariser as a no-network fallback, so the feature degrades rather than fails."*
