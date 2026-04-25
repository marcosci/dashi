import {useDropzone} from "react-dropzone";

interface Props {
  file: File | null;
  onFile: (file: File | null) => void;
  disabled?: boolean;
  maxBytes: number;
}

export function FileDropzone({file, onFile, disabled, maxBytes}: Props) {
  const {getRootProps, getInputProps, isDragActive} = useDropzone({
    multiple: false,
    disabled,
    maxSize: maxBytes,
    onDrop: (accepted) => onFile(accepted[0] ?? null),
  });

  return (
    <div
      {...getRootProps()}
      className={[
        "border-2 border-dashed rounded-lg px-6 py-10 text-center transition cursor-pointer",
        isDragActive ? "border-amber bg-amber/10" : "border-cream/20 hover:border-cream/40",
        disabled ? "opacity-50 pointer-events-none" : "",
      ].join(" ")}
    >
      <input {...getInputProps()} aria-label="upload-file" />
      {file ? (
        <div>
          <div className="font-mono text-sm text-amber-light">{file.name}</div>
          <div className="text-xs text-cream/60 mt-1">
            {(file.size / (1024 * 1024)).toFixed(2)} MiB · {file.type || "application/octet-stream"}
          </div>
          <button
            type="button"
            className="mt-3 text-xs text-cream/60 hover:text-seal"
            onClick={(e) => {
              e.stopPropagation();
              onFile(null);
            }}
          >
            remove
          </button>
        </div>
      ) : (
        <div className="text-cream/70">
          <div className="text-sm">drop a file here or <span className="text-amber underline">browse</span></div>
          <div className="text-xs text-cream/40 mt-1">
            max {(maxBytes / (1024 * 1024)).toFixed(0)} MiB · GeoTIFF, Shapefile, GPKG, KML, LAZ, COPC, GeoParquet, …
          </div>
        </div>
      )}
    </div>
  );
}
