# Technical Documentation

This document explains how the analysis was conducted and why certain decisions were made, from the initial assumptions and data verification to the technical choices behind each stage of the project.

## 1. Background & Objective

**Dataset overview.** The dataset contains e-commerce transactions covering January 1, 2021, to December 31, 2025. It consists of five files: orders (138,116 rows), order items (397,569 rows), customers (25,000 rows), products (1,175 rows), and one summary file.

**Project objective.** The analysis was designed to answer six business questions:

1. Which marketing channels and campaigns contribute the most to sales and profit?
2. Does the channel with the highest revenue also generate the highest profit?
3. Which customer segments are the most valuable?
4. What are the purchasing and repeat purchase patterns?
5. Do discounts and coupons support sales, or do they reduce profitability?
6. Which products, brands, and categories contribute the most to profit?

**Analytical approach.** The process followed a clear sequence: business questions → data suitability checks → metric definitions → data validation → analysis → presentation.

The reasoning behind this approach is straightforward: the reliability of any conclusion depends on the quality of the underlying data and the definitions used to measure it.

## 2. Initial Assumptions vs. What Verification Showed

At the beginning of the project, several assumptions were made based on the dataset description. Rather than accepting them as facts, I tested each one before using the data. Several assumptions turned out to be inaccurate, which led to important changes in the analytical approach.

| Initial assumption | What verification showed | Decision |
|---|---|---|
| `net_sales` represents revenue | It already includes tax and shipping costs | Recalculate: **Net Revenue = gross − discount** |
| `profit` represents actual profit | It includes tax, which accounts for 22.2% of the reported profit | **Gross Profit = Net Revenue − product cost** |
| All orders represent sales | 17.8% of orders were not Completed (Returned 6.9%, Cancelled 6.1%, Pending 4.8%) | **Valid sales = Completed orders**. Returned orders are analyzed separately |
| The orders and order items tables are consistent | 11,226 orders (8.1%) could not be reconciled: the order items table contains 31,591 additional rows that do not match the orders table | Flag affected rows using `is_reconciled_line`; product analysis uses matched rows |
| `order_id` + `product_id` can serve as the item key | 87 duplicate pairs were found | Create a separate `line_id` |
| The summary file can be used as the reference | It was calculated across all order statuses, and one column ("Total Products Used") was incorrect | Use it for comparison only |
| Lifetime value and the repeat customer indicator can be used | CLV is based on historical `net_sales` from a larger dataset than the files provided (approximately 11,845 missing orders, affecting 37.8% of customers) and could not be verified | **Not used**. Customer segmentation is performed independently using RFM |
| Customer Acquisition Cost (CAC) can be analyzed by channel | It is not associated with channel, segment, or customer value | **Not used** |
| Acquisition cohorts can be created | Customer orders are distributed throughout the observation period, causing the number of "new customers" to decline each year simply because of the observation window | Replaced with RFM |
| Campaigns can be compared | 60% of orders have no campaign tag, 17% are tagged as `Default_Campaign`, and TikTok and YouTube orders have no campaign information | Compare only **named campaigns (23% of orders)** |
| Coupons are a discount mechanism | Coupons appear in 20% of orders but are not associated with discount levels | Focus on **discount depth** |
| ROAS, CPA, and conversion rate can be calculated | Campaign cost, impression, and click data are unavailable | **Not calculated** |

## 3. Why Python, SQL, and Power BI

Each tool was selected for a specific stage of the analysis rather than using multiple tools to perform the same tasks.

| Stage | Tool | Reason |
|---|---|---|
| Data exploration and cleaning | **Python** | Useful for examining distributions and outliers through visualizations, checking multiple conditions at once, and cleaning data incrementally without modifying the original files |
| Business metric calculations | **MySQL** | Business logic can be defined once, reproduced, and audited by others. It is also suitable for large-scale aggregations. Window functions and CTEs simplify calculations such as contribution share, YoY changes, and RFM |
| Result presentation | **Power BI** | Allows non-technical audiences to explore the results through filters, such as year and customer segment, without writing code |

**How the tools work together:** Python helps identify patterns and data quality issues, SQL turns the validated logic into the official business metrics, and Power BI presents the results. Since all dashboard figures are sourced from SQL, the numbers can be cross-checked across all three stages.

## 4. Data Model

Four tables were loaded into MySQL, while the summary file was retained for comparison purposes only.

| Table | Contents | One row represents |
|---|---|---|
| `dim_customer` | Customer profiles | One customer |
| `dim_product` | Product catalog | One product |
| `fact_orders` | Orders, monetary values, channels, and discounts | One order |
| `fact_order_items` | Product-level order details | One product within an order |

The relationships follow a one-to-many structure: one customer can have multiple orders, one order can contain multiple items, and one product can appear in multiple order items. These relationships were verified, with no orphan records found.

**Design decisions:**

- Customer attributes (age, segment, and country) are stored only in `dim_customer` because their values were found to be 100% identical in the orders table. Storing the same attributes twice could introduce inconsistencies.
- `fact_order_items` uses `line_id` as its primary key.
- Missing values that carry business meaning, such as orders that were not returned, orders without coupons, and orders that have not been shipped, are retained as NULL rather than filled with arbitrary values.

## 5. Python: Understanding, Quality Checks, and Cleaning

**5.1 Initial inspection.**

Each dataset was examined for its dimensions, data types, missing values, duplicates, and descriptive statistics. No duplicate rows were found. Missing values were present only in the orders table, totaling 573,828 cells.

**5.2 Understanding missing values.**

Further inspection showed that the missing values had specific meanings:

- Empty return-related fields indicated that an order had not been returned (128,654 orders).
- Empty coupon fields indicated that no coupon was used.
- Missing shipping and rating information appeared in 24,557 orders, exactly matching the combined number of Cancelled, Pending, and Returned orders.

Based on these findings, no imputation was performed.

**5.3 Data quality checks.**

The issues described in Section 2 were investigated at this stage. The checks covered key uniqueness, relationships between tables, monetary column definitions, order-to-item reconciliation, item-to-product catalog matching, and consistency between the summary file and the underlying data.

**5.4 Exploratory data analysis.**

The exploration included visualizations of order status, orders by channel, monthly trends, order value distributions, boxplots, discount distributions, monthly discount patterns, and customer and product profiles.

Several findings influenced the direction of the analysis:

- **The business showed little overall growth and clear seasonality.** Annual revenue changed by less than 3%, with recurring increases in November and December. As a result, the analysis focused less on growth and more on comparisons across groups and seasons.
- **Discounts were present in almost every order**, with an average discount rate of 17.4%. This made discount depth a more useful comparison than simply separating orders into discounted and non-discounted groups.
- **Discount patterns followed a recurring calendar trend:** approximately 11% in most months, 16% in September, 24% in July, and 33% in November and December.
- **Outliers were retained.** High-value orders were associated with larger quantities or more expensive products rather than data entry errors.

**5.5 Data cleaning.**

All cleaning operations were performed on copies of the original datasets. The source files were left unchanged.

| Step | Reason |
|---|---|
| Remove names, cities, postal codes, and review text | These fields contain personal information, are not required for the analysis, and should not be included in a publicly shared portfolio |
| Rename original columns to `invoice_total`, `reported_profit`, `reported_clv`, etc. | To make it clear that these fields should not be used directly as KPIs |
| Add `net_revenue`, `gross_profit`, and `discount_rate` | To establish consistent revenue and profit definitions that exclude tax |
| Add `is_valid_sale`, `is_returned`, `has_coupon`, and `payment_pending` flags | To simplify filtering in SQL and Power BI |
| Add `campaign_group` (Named, Default, Not tagged) | To ensure that only named campaigns are included in campaign comparisons |
| Add `discount_season` (Regular, Light, Medium, Heavy) | To compare promotional and regular months. **These categories are derived from observed data patterns**, not an official promotional calendar |
| Add the `is_reconciled_line` flag to order items | To address the 11,226 unreconciled orders. After reconciliation flags were applied, the item total matched the order total (189,962,560.88) |
| Add `age_band` | To group customers by age for filtering |

**5.6 Validation and export.**

Validation confirmed that the row counts remained unchanged before and after cleaning. Valid sales revenue also matched exactly between the original and cleaned datasets (127,907,006.57). No personal information or missing key values remained in the cleaned data.

The final output consisted of four cleaned CSV files.

## 6. MySQL: Storage and Analysis

**6.1 Schema design and data loading.**

Tables were created using appropriate data types, including `DECIMAL` for monetary values, along with primary keys and foreign keys. The data was then loaded using `LOAD DATA INFILE`.

Post-loading validation covered row counts (25,000 / 1,175 / 138,116 / 397,569), valid sales revenue, item totals compared with orders, and NULL counts. All results matched the Python validation.

**6.2 Analytical queries.**

Each SQL query was designed to answer a specific business question.

| Query | Business question | Technique |
|---|---|---|
| Summary KPIs | Total revenue, profit, margin, AOV, and return rate | Aggregation |
| Channel performance | #1, #2 | `GROUP BY`, `SUM() OVER ()` for contribution share |
| Annual and seasonal trends | #4 | CTE, `LAG()`, `AVG() OVER ()` |
| Campaign contribution | #1 | Campaign group filtering, `RANK()` |
| Customer segment value | #3 | `JOIN` with the customer dimension |
| RFM segmentation | #3, #4 | CTE, `NTILE()`, `CASE` |
| Margin by discount band | #5 | `CASE` |
| Discount season performance | #5 | Daily aggregation |
| Category, brand, and product performance | #6 | Views, `RANK()`, `ROW_NUMBER() OVER (PARTITION BY ...)` |
| Returns by channel, category, and reason | Additional analysis | Conditional aggregation |
| Coupon vs. no coupon | #5 | Aggregation by flag |

**RFM note.** A fixed reference date of January 1, 2026, was used. `NTILE(5)` was applied to Recency and Monetary, while Frequency used fixed thresholds (≤2, 3, 4, 5–6, and ≥7 orders). This approach was chosen because thousands of customers had the same order frequency, and using `NTILE` would arbitrarily split customers with identical values across different groups.

**6.3 Views for Power BI.**

Three SQL views were created to centralize the business definitions used in the dashboard:

- `vw_fact_orders`
- `vw_dim_customer`
- `vw_valid_lines`

## 7. Power BI: Model, Measures, and Dashboard

**7.1 Data import method.**

A direct connection from Power BI to MySQL did not work on my device. As a workaround, the three SQL views were exported to CSV files and imported into Power BI.

This did not affect the figures because all calculations and business logic remained in SQL. In a production environment, a direct database connection with scheduled refreshes would be preferable.

**7.2 Data model.**

The Power BI model consists of a `Date` table (created using DAX), `vw_dim_customer`, `vw_fact_orders`, and `vw_valid_lines`.

Three one-to-many relationships with single-direction filtering were established. As a result, filters such as year, channel, and customer segment also filter the order item table automatically.

**7.3 Main DAX measures.**

All main measures use Completed orders as the basis for valid sales.

| Measure | Definition |
|---|---|
| Net Revenue | Sum of `net_revenue` from valid sales |
| Gross Profit | Sum of `gross_profit` from valid sales |
| Gross Margin % | Gross Profit ÷ Net Revenue, calculated from totals rather than averaging row-level margins |
| Orders, AOV | Count of valid orders; Net Revenue ÷ Orders |
| Discount Rate % | Total discount ÷ total gross sales |
| Return Rate % | Returned ÷ (Completed + Returned) |
| Orders per Day, Profit per Day | Calculated by dividing the corresponding totals by the number of days with orders |
| Item Revenue, Item Profit, Item Margin % | Calculated using matched order item rows |

**7.4 Dashboard design.**

The dashboard is organized into three pages, each focusing on a different area of the analysis.

| Page | Main question |
|---|---|
| Marketing Performance Overview | Which channels contribute the most, and does higher revenue translate into higher profit? |
| Customer Behavior & Retention | Which customers are the most valuable, and how do customer groups differ? |
| Promotion & Product Performance | Do discounts preserve profitability, and which products contribute the most? |

Each page also includes a footnote describing the relevant data limitations.

**7.5 Reconciliation.**

Dashboard figures were cross-checked against SQL results:

- Net Revenue: $127,907,006.57
- Gross Profit: $45,998,727.67
- Gross Margin: 35.96%
- Orders: 113,559
- AOV: $1,126.35
- Discount Rate: 19.53%
- Return Rate: 7.69%

Revenue calculated from the orders table and the order items table matched exactly.

## 8. Key Findings & Evidence

The following table summarizes the main findings alongside the evidence supporting each conclusion.

| Business question | Finding | Evidence |
|---|---|---|
| Channel and campaign performance | Contributions largely followed order volume. Organic Search contributed 20.2%, Google Ads 15.1%, and Direct 14.7% | Revenue share was approximately equal to profit share across all channels |
| Does higher revenue mean higher profit? | Not necessarily. Margins across channels ranged from 35.7% to 36.2% | The difference between the highest and lowest channel margins was only 0.54 percentage points |
| Customer segments | Premium and VIP customers generated 12% less profit per customer | Discounts averaged 22.8% vs. 17.6%, while purchase frequency and revenue per customer were similar |
| Purchasing patterns | Customers placed an average of 4.6 orders, with approximately 15,000 active customers each year. The business remained relatively flat, with peaks in November and December | Annual changes were below 2.1%, while seasonal indices reached 1.48 in November and 1.58 in December |
| RFM segments | Champions (25% of customers) contributed 36% of revenue. At Risk customers (3,024 customers) had high customer value but had not ordered for a long time | At Risk customers generated $2,389 in profit per customer |
| Discounts | Margin declined from 45.9% to −14.3%, with a break-even point at approximately 48% discount. A total of 2,397 orders generated losses | Discount band analysis showed that 6.1% of orders had discounts above 40% |
| Discount seasonality | In November and December, orders per day increased to 90.6 from 56.4, but profit per day decreased by approximately 7%. In July, with an average discount of 24%, orders per day did not increase and profit per day fell by approximately 18% | Daily performance comparison |
| Coupon usage | No measurable impact was observed | With and without coupons: discount rate was 19.53%, while margins were 35.95% and 36.01%, respectively |
| Category and product performance | Electronics contributed 21.6% of revenue but only 15.3% of profit, with a margin of 25.4%. The three leading categories contributed 39.7% of total profit | Grocery and Books had higher margins of 53.9% and 50.9%, respectively, but smaller contributions |
| Returns | The overall return rate was 7.69%, with no major concentration in a particular group | Return rates ranged from 7.5%–7.9% across channels and 7.4%–8.2% across categories |

## 9. Recommendations

These recommendations should be treated as hypotheses to test, not as proven cause-and-effect relationships.

1. Set discount limits at around 40%, considering that the break-even point is approximately 48%.
2. Test smaller discounts during July and the November–December promotional period, then compare the resulting profit.
3. Review discount policies for VIP and Premium customers and consider offering non-price benefits instead.
4. Run win-back campaigns targeting the At Risk customer segment.
5. Avoid allocating marketing budgets based solely on revenue contribution. Start tracking campaign costs, impressions, and clicks, and ensure that every campaign is properly tagged.
6. Improve Electronics margins through pricing adjustments, purchasing cost reductions, or product bundling.

## 10. Limitations & Assumptions

- Campaign cost, impression, and click data were unavailable. Therefore, ROAS, CPA, and conversion rate could not be calculated.
- No control group was available, so all observed relationships represent associations rather than proven causal effects.
- Approximately 7.9% of orders (11,845) belonging to 37.8% of customers were missing from the dataset. Customer metrics are therefore based on the available order history.
- Valid sales are defined as Completed orders. Approximately 10% of these orders still had a Pending payment status but were included in the analysis.
- Currency values are assumed to use a single scale. The `currency` column functions only as a country label.
- Discount season categories were derived from observed data patterns rather than an official promotional calendar.
- Several variables, including channel, coupon usage, purchase time, and purchase day, showed no observable relationship with the outcomes. These results are reported as they are: no measurable relationship was found in this dataset.
- Acquisition cohorts were not created because the observation window could produce misleading results.

## 11. How to Reproduce

1. Run `notebooks/01_python_eda_and_cleaning.ipynb` to generate the four cleaned CSV files.
2. Execute the scripts in the `sql/` directory in order: schema creation, data loading, validation, analysis, and view creation.
3. Export the three SQL views to CSV files (or connect Power BI directly to MySQL), then open the dashboard.

## 12. What I Learned

- Checking column definitions before starting an analysis can significantly change the results. In this project, the original reported profit included approximately 22% tax.
- Finding no significant difference between groups, such as marketing channels, is still a valid analytical finding.
- A relationship between two variables does not automatically imply causation, especially when the highest sales occur alongside the deepest discounts.