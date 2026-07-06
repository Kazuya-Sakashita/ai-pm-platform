require "yaml"

module OpenApiDraftGeneration
  class DeterministicProvider
    MODEL_NAME = "deterministic-openapi-draft-placeholder-v1"

    def generate(requirement)
      @requirement = requirement

      {
        status: "draft",
        title: title,
        content: yaml_content,
        validation_errors: [],
        generated_by_model: MODEL_NAME
      }
    end

    private

    attr_reader :requirement

    def yaml_content
      YAML.dump(openapi_document).sub(/\A---\s*\n/, "")
    end

    def openapi_document
      {
        "openapi" => "3.1.0",
        "info" => {
          "title" => title,
          "version" => "0.1.0",
          "description" => requirement.goal
        },
        "paths" => {
          path_name => {
            "post" => {
              "summary" => primary_functional_requirement,
              "operationId" => operation_id,
              "requestBody" => {
                "required" => true,
                "content" => {
                  "application/json" => {
                    "schema" => { "$ref" => "#/components/schemas/GeneratedRequest" }
                  }
                }
              },
              "responses" => {
                "201" => {
                  "description" => "作成済み",
                  "content" => {
                    "application/json" => {
                      "schema" => { "$ref" => "#/components/schemas/GeneratedResponse" }
                    }
                  }
                }
              },
              "x-source-requirement" => source_requirement
            }
          }
        },
        "components" => {
          "schemas" => {
            "GeneratedRequest" => {
              "type" => "object",
              "additionalProperties" => true
            },
            "GeneratedResponse" => {
              "type" => "object",
              "required" => ["id", "status"],
              "properties" => {
                "id" => { "type" => "string", "format" => "uuid" },
                "status" => { "type" => "string" }
              }
            }
          }
        }
      }
    end

    def title
      base = requirement.goal.to_s.squish
      base = primary_functional_requirement if base.blank?

      "OpenAPIドラフト: #{base}".truncate(120)
    end

    def path_name
      "/#{resource_slug}"
    end

    def operation_id
      "create#{resource_slug.camelize}"
    end

    def resource_slug
      slug = primary_functional_requirement.parameterize
      slug = requirement.goal.to_s.parameterize if slug.blank?
      slug = "generated-artifact" if slug.blank?

      slug[0, 60].sub(/-+\z/, "")
    end

    def primary_functional_requirement
      functional_requirements.first || "承認済み要件向けのAPIエンドポイントを作成する。"
    end

    def functional_requirements
      Array(requirement.functional_requirements).filter_map do |item|
        item.to_s.sub(/\AFR-\d+:\s*/, "").strip.presence
      end
    end

    def source_requirement
      {
        "id" => requirement.id,
        "status" => requirement.status,
        "acceptanceCriteria" => requirement.acceptance_criteria,
        "risks" => requirement.risks
      }
    end
  end
end
