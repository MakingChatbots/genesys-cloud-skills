# Genesys Cloud AI Agent Skills

A collection of reusable AI Agent [skills](https://skills.sh/docs) for working with the Genesys Cloud platform.

## Skills

| Skill                               | Description                                                                                                        |
|-------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| [platform-api](skills/platform-api) | Queries the Genesys Cloud Platform API schema for endpoint details, permissions, parameters, and response formats. |

## Installation

Install the skills using the [skills CLI](https://skills.sh/docs):

```bash
npx skills add MakingChatbots/genesys-cloud-skills
```

## License

This repository is licensed under the [MIT License](LICENSE).

**Note:** The Genesys Cloud Platform API schema (`schema.json`), downloaded by the `platform-api` skill, is the property of Genesys and is subject to the [Genesys Cloud Terms and Conditions](https://help.genesys.cloud/articles/global-genesys-cloud-service-terms-and-conditions/). It is not covered by this repository's MIT Licence.
