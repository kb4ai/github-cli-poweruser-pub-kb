
First ensure you exported your `GITHUB_TOKEN`:

```
# https://github.com/settings/tokens
export GITHUB_TOKEN='YOUR GITHUB TOKEN'
```


Basicaly we need to know ID of gien option, if we would like later to modify it to sth else.

So first we query what are option IDs and later , which options has each field so we read what single select option values have project cards.

```
## Select Options Available and Their IDs (in case we would like to run mutation)
┌────────────┬──────────────────────────────┬──────────────┬────────────────────────────────┐
│ Field Name │ Text of Single Select Option │ OPTION_ID    │            FIELD_ID            │
├────────────┼──────────────────────────────┼──────────────┼────────────────────────────────┤
│ Status     │ A                            │ 18c5b393     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ Status     │ B                            │ d29b7e2d     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ Status     │ C                            │ 58e2f5d4     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ TestField  │ TestOptionA                  │ 034d9f5a     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
│ TestField  │ TestOptionB                  │ 4f242672     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
│ TestField  │ TestOptionC                  │ aec93933     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
└────────────┴──────────────────────────────┴──────────────┴────────────────────────────────┘

## List of Statuses of Fields
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────┬────────────────────────────────┬──────────────────────────────┬──────────────────────────────┐
│                                           Text of field Title                                           │ Text of Status │          Id of Status          │       Id of Text field       │          ITEM_ID             │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────┼────────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Github Repositories Configure Privately Disclosing Security Policies                                    │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJla5U │
│ How to name repository for issues/docs regarding Policies, Guildelines, MISC Organisational documents ? │ A              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlatA │
│ Chaos Engineering in DevOps: https://github.com/ExampleOrg/demo-k8s-operator/labels/chaos_engineering   │ C              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlato │
│ Profiling, measuring LSP Tooling                                                                        │ C              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlatU │
│ 23Q3 Inventory of items (sync with Ops)                                                                 │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlas8 │
│ Risk Management                                                                                         │ A              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlat0 │
│ 23Q3 Why I can not create Slack channels visible for ExampleOrg?                                        │ A              │ PVTSSF_lADOExample123456789    │ PVTF_lADOExample567890123    │ PVTI_lADOExample777777777    │
│ test dependencies | #Blocked                                                                            │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJla5Q │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────┴────────────────────────────────┴──────────────────────────────┴──────────────────────────────┘
```

## Chainging Single Select Field  Value


Let's take values from above output and see how we can change `Status` from `C` to `B` for `Chaos Engineering...` issue project card.


Using : https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects#updating-a-single-select-field


```
$ ./step_05_SET_single_select_field.sh -h
Usage:-n./step_05_SET_single_select_field.sh FIELD_ID ITEM_ID OPTION_ID  [PROJECT_ID] # otherwise will use defaults

$ ./step_05_SET_single_select_field.sh PVTSSF_lADOA1ZjX84AWImYzgOJVwA  PVTI_lADOA1ZjX84AWImYzgJlato  d29b7e2d
{
  "data": {
    "updateProjectV2ItemFieldValue": {
      "projectV2Item": {
        "id": "PVTI_lADOA1ZjX84AWImYzgJlato"
      }
    }
  }
}
```


And let's check result afterwards:


```
./run_steps_01_to_04_project_statues_read.sh 
## Select Options Available and Their IDs (in case we would like to run mutation)
┌────────────┬──────────────────────────────┬──────────────┬────────────────────────────────┐
│ Field Name │ Text of Single Select Option │ OPTION_ID    │            FIELD_ID            │
├────────────┼──────────────────────────────┼──────────────┼────────────────────────────────┤
│ Status     │ A                            │ 18c5b393     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ Status     │ B                            │ d29b7e2d     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ Status     │ C                            │ 58e2f5d4     │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │
│ TestField  │ TestOptionA                  │ 034d9f5a     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
│ TestField  │ TestOptionB                  │ 4f242672     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
│ TestField  │ TestOptionC                  │ aec93933     │ PVTSSF_lADOA1ZjX84AWImYzgORh5k │
└────────────┴──────────────────────────────┴──────────────┴────────────────────────────────┘

## List of Statuses of Fields
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────┬────────────────────────────────┬──────────────────────────────┬──────────────────────────────┐
│                                           Text of field Title                                           │ Text of Status │          Id of Status          │       Id of Text field       │          ITEM_ID             │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────┼────────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ Github Repositories Configure Privately Disclosing Security Policies                                    │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJla5U │
│ How to name repository for issues/docs regarding Policies, Guildelines, MISC Organisational documents ? │ A              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlatA │
│ Chaos Engineering in DevOps: https://github.com/ExampleOrg/demo-k8s-operator/labels/chaos_engineering   │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlato │
│ Profiling, measuring LSP Tooling                                                                        │ C              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlatU │
│ 23Q3 Inventory of items (sync with Ops)                                                                 │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlas8 │
│ Risk Management                                                                                         │ A              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJlat0 │
│ 23Q3 Why I can not create Slack channels visible for ExampleOrg?                                        │ A              │ PVTSSF_lADOExample123456789    │ PVTF_lADOExample567890123    │ PVTI_lADOExample777777777    │
│ test dependencies | #Blocked                                                                            │ B              │ PVTSSF_lADOA1ZjX84AWImYzgOJVwA │ PVTF_lADOA1ZjX84AWImYzgOJVv4 │ PVTI_lADOA1ZjX84AWImYzgJla5Q │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────┴────────────────────────────────┴──────────────────────────────┴──────────────────────────────┘
```
