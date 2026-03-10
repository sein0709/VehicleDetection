"""GreyEye Inference Worker — detection, tracking, classification pipeline."""

__version__ = "0.1.0"

from inference_worker.pipeline import InferencePipeline
from inference_worker.worker import InferenceWorker

__all__ = ["InferencePipeline", "InferenceWorker"]
