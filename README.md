# SprintEmailGenerator
Little tool to generate emails for the sprint report.

Before the generator can be used, you must generate and save an API key in application.yml.

To generate an email for a sprint, just run the script via the command line with:

```
  ruby generate.rb {sprint number}
```

This also needs to be updated every year - simply change the "YEAR" constant in the Generator class to the current year.
