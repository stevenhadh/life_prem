# Life Insurance Pricing and Reserves App

An interactive R Shiny application for pricing whole life and term insurance products using SSA mortality tables and life contingency formulas.

## What It Does

This app uses period life tables from the Social Security Administration to compute net premiums and projected reserves for whole life and $n$-term insurance products under the equivalence principle.

Users adjust four inputs in real time (**issue age**, **sex**, **interest rate**, **term length**) and observe immediate updates across all outputs.

**Outputs:**

- Net annual premium
- Net single premium
- EPV per dollar of death benefit
- EPV per dollar of annuity-due
- Sensitivity charts across age, interest rate
- Reserve projection over policy lifetime

**Assumptions:**

- Premiums are paid at the beginning of each policy year
- The death benefit is paid at the end of the year of death
- No lapses or surrenders
- Constant interest rate
- No profit/expense loadings

## Dataset

Mortality rates are drawn from the **2023 SSA Period Life Tables**, which publish $q_x$ (probability of death at exact age $x$) for single-year age groups, separated by males and females. This table is used directly, there are no adjustments or mortality projections.

## Actuarial Formulas

### Notation

| Symbol | Meaning |
|---|---|
| $x$ | Age at issue |
| $q_{x+k}$ | Probability of death between ages $x+k$ and $x+k+1$ |
| ${}_kp_x$ | Probability of surviving $k$ years from age $x$ |
| $v = \frac{1}{1+i}$ | Annual discount factor |
| $P$ | Net annual premium |

Survival probabilities are computed directly from the $l_x$ column of the SSA table:

$${}_kp_x = \frac{l_{x+k}}{l_x}$$

### Expected Present Value of Benefits

**Whole life insurance** — EPV of $1 payable at end of year of death:

$$A_x = \sum_{k=0}^{\omega - x - 1} v^{k+1} \cdot {}_kp_x \cdot q_{x+k}$$

**$n$-year term insurance** — benefit only if death occurs within $n$ years:

$$A^1_{x:\overline{n}|} = \sum_{k=0}^{n-1} v^{k+1} \cdot {}_kp_x \cdot q_{x+k}$$

Each term in the sum is the discounted probability of dying in exactly year $k+1$: survive $k$ years, then die. The benefit is discounted $k+1$ periods because payment occurs at the end of that year.

### Expected Present Value of Premiums

Premiums are modeled as a life annuity-due, paid at the start of each year the insured is alive.

**Whole life annuity-due:**

$$\ddot{a}_x = \sum_{k=0}^{\omega - x - 1} v^k \cdot {}_kp_x$$

**$n$-year temporary life annuity-due:**

$$\ddot{a}_{x:\overline{n}|} = \sum_{k=0}^{n-1} v^k \cdot {}_kp_x$$

The $k=0$ term equals 1 in both cases where the first premium is paid with certainty at issue, discounted zero periods.

### The Equivalence Principle

The net premium $P$ is set so that the expected present value of what the insurer pays out equals the expected present value of what the policyholder pays in:

$$\text{EPV(Benefits)} = \text{EPV(Premiums)}$$

**Whole life:**

$$P(A_x) = \frac{A_x}{\ddot{a}_x}$$

**$n$-year term:**

$$P\!\left(A^1_{x:\overline{n}|}\right) = \frac{A^1_{x:\overline{n}|}}{\ddot{a}_{x:\overline{n}|}}$$

No profit loading is included. The net premium is the pure break-even amount under the given mortality and interest assumptions.

### Reserves

Reserves are computed by the prospective method. At policy duration $t$, the reserve is the EPV of future benefits minus the EPV of future premiums using the same fixed premium $P$ at the attained age $x + t$ .

**Prospective reserve at duration $t$:**

$$_tV = A_{x+t} - P \cdot \ddot{a}_{x+t}$$

For term insurance, remaining term is $n - t$. Once $t \geq n$, the reserve is zero so no further liability exists after the coverage period ends.

For whole life, the reserve approaches the face amount, reflecting the certainty of the eventual claim.

## Screenshots

<img width="758" height="638" alt="image" src="https://github.com/user-attachments/assets/bf8d1048-2f20-42dd-8027-5bb976b8614d" />
<img width="812" height="805" alt="image" src="https://github.com/user-attachments/assets/8d65f8be-01ba-40e9-b86d-f39beadec29a" />
<img width="812" height="814" alt="image" src="https://github.com/user-attachments/assets/7200d7b7-da20-44d7-af8d-e45b2bbdda4e" />

## Getting Started

```r
install.packages(c("shiny", "ggplot2"))
shiny::runApp("app.R")
```
