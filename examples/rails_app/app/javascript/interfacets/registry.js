import { withTransform } from "interfacets/withTransform";
import Button from "../components/Button";
const textarea = "textarea";

export const registry = {
  Button,
  textarea: withTransform(textarea, {"onChange":{"value":[0,"target","value"]}}),
};
